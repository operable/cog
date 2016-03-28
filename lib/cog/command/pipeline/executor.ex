defmodule Cog.Command.Pipeline.Executor do

  @type adapter_name :: String.t
  @type redirect_destination :: map

  @typedoc """
  Custom State for executor

  ## Fields

  * `:id` - Generated id for the pipeline executor.
  * `:topic` - The topic that the executor listens on.
  * `:started` - Timestamp for the start of the pipeline.
  * `:mq_conn` - The message queue connection.
  * `:request` - The original request from the adapter.
  * `:raw_destinations` - redirect destinations as typed by the user,
    prior to any processing
  * `:destinations` - Destinations to which pipeline output will be
    returned.
  * `:invocations` - list of all the invocation ASTs for the
    pipeline. Execution plans will be created from these.
  * `:current_plan` - The current execution plan being executed.
  * `:plans` - The remaining execution plans for the pipeline.
  * `:output` - The accumulated output of the execution plans executed
    so far for the current command invocation. This will feed into
    subsequent pipeline stages as the "context"
  * `:user` - the Cog User model for the invoker of the pipeline
  * `:user_permissions` - a list of the fully-qualified names of all
    permissions that `user` has (recursively). Used for permission
    checking against the invocation rules of the commands in the
    pipeline.
  * `:error_type` - an atom indicating what kind of error has
    occurred. Will be `nil` in the case of a successfully-executed
    pipeline.
  * `:error_message` - additional information about the error that has
    occurred. Only set if `:error_type` is non-nil.
  """
  @type state :: %__MODULE__{
    id: String.t,
    topic: String.t,
    started: :erlang.timestamp(),
    mq_conn: Carrier.Messaging.Connection.connection(),
    request: %Spanner.Command.Request{}, # TODO: needs to be a type
    raw_destinations: [String.t],
    destinations: %{adapter_name => [redirect_destination]},
    invocations: [%Piper.Command.Ast.Invocation{}], # TODO: needs to be a type
    current_plan: Cog.Command.Pipeline.Plan.t,
    plans: [Cog.Command.Pipeline.Plan.t],
    output: [{Map.t, String.t}], # {output, template}
    user: %Cog.Models.User{},
    user_permissions: [String.t],
    error_type: atom(),
    error_message: String.t
  }
  defstruct [
    id: nil,
    topic: nil,
    mq_conn: nil,
    request: nil,
    raw_destinations: [],
    destinations: %{},
    invocations: [],
    current_plan: nil,
    plans: [],
    output: [],
    started: nil,
    user: nil,
    user_permissions: [],
    error_type: nil,
    error_message: nil
  ]

  @behaviour :gen_fsm

  # Timeout for commands once they are in the `run_command` state
  @command_timeout 60000

  alias Carrier.Messaging.Connection
  alias Cog.Command.CommandResolver
  alias Cog.Command.PermissionsCache
  alias Cog.Events.PipelineEvent
  alias Cog.Queries
  alias Cog.Repo
  alias Cog.TemplateCache
  alias Piper.Command.Ast
  alias Piper.Command.Parser
  alias Piper.Command.ParserOptions

  use Adz

  def start_link(request),
    do: :gen_fsm.start_link(__MODULE__, [request], [])

  def init([request]) when is_map(request) do
    request = sanitize_request(request)
    {:ok, conn} = Connection.connect()
    id = Map.fetch!(request, "id")
    topic = "/bot/pipelines/#{id}"
    Connection.subscribe(conn, topic <> "/+")

    case create_initial_context(request) do
      {:ok, initial_context} ->
        case fetch_user_from_request(request) do
          {:ok, user} ->
            {:ok, perms} = PermissionsCache.fetch(user)
            loop_data = %__MODULE__{id: id, topic: topic, request: request,
                                    mq_conn: conn,
                                    user: user,
                                    user_permissions: perms,
                                    output: initial_context,
                                    started: :os.timestamp()}
            initialization_event(loop_data)
            {:ok, :parse, loop_data, 0}
          {:error, :not_found} ->
            alert_unregistered_user(%__MODULE__{mq_conn: conn, request: request})
            :ignore
        end
      :error ->
        # TODO: Once externally-triggered pipelines are A Thing and we
        # sort out how and where to send error messages, this can be
        # improved. For now, we'll just log and exit
        Logger.error("Bad initial context provided; all values must be maps: #{inspect request}")
        :ignore
    end
  end

  def parse(:timeout, state) do
    options = %ParserOptions{resolver: CommandResolver.command_resolver_fn(state.user)}
    case Parser.scan_and_parse(state.request["text"], options) do
      {:ok, %Ast.Pipeline{}=pipeline} ->
        {:next_state, :resolve_destinations, %{state |
                                               raw_destinations: Ast.Pipeline.redirect_targets(pipeline),
                                               invocations: Enum.to_list(pipeline)}, 0}
      {:error, msg} ->
        send_reply(msg, state)
        fail_pipeline(state, :parse_error, "Error parsing command pipeline '#{state.request["text"]}': #{msg}")
    end
  end

  def resolve_destinations(:timeout, %__MODULE__{raw_destinations: destinations}=state) do
    redirs = case destinations do
               [] ->
                 # If no redirects were given, we default to the
                 # current room; this keeps things uniform later on.
                 {:ok, [{state.request["adapter"], state.request["room"]}]}
               _ ->
                 {ok, errors} = destinations
                 |> Enum.map(&lookup_room(&1, state))
                 |> Enum.partition(&match?({:ok, _}, &1))

                 case errors do
                   [] ->
                     destinations = Enum.map(ok, fn({:ok, val}) -> val end)
                     {:ok, destinations}
                   _ ->
                     errors = Enum.map(errors, fn({:error, val}) -> val end)
                     {:error, errors}
                 end
             end
    case redirs do
      {:ok, destinations} ->
        destinations = Enum.reduce(destinations, %{},
          fn({adapter, destination}, acc) ->
            Map.update(acc, adapter, [destination], &([destination|&1]))
          end)

        {:next_state, :plan_next_invocation, %{state | destinations: destinations}, 0}
      {:error, invalid} ->
        message = redirection_error_message(invalid)
        send_error(message, state)
        fail_pipeline(state, :redirect_error, "Invalid redirects were specified: #{inspect invalid}")
    end
  end

  def plan_next_invocation(:timeout, %__MODULE__{invocations: [current_invocation|remaining],
                                                 output: previous_output,
                                                 user_permissions: permissions}=state) do

    # If a previous command generated output, we don't need to retain
    # any templating information, because the current command now
    # controls how the output will be presented
    context = strip_templates(previous_output)

    case Cog.Command.Pipeline.Planner.plan(current_invocation, context, permissions) do
      {:ok, plans} ->
        {:next_state, :execute_plan, %{state |
                                       output: [],
                                       current_plan: nil,
                                       plans: plans,
                                       invocations: remaining}, 0}
      {:error, {:missing_key, var}} ->
        send_reply("I can't find the variable '$#{var}'.", state)
        fail_pipeline(state, :binding_error, "Error preparing to execute command pipeline '#{state.request["text"]}': Unknown variable '#{var}'")
      {:error, :no_rule} ->
        why = "No rules match the supplied invocation of '#{current_invocation}'. Check your args and options, then confirm that the proper rules are in place."
        send_denied(current_invocation, why, state)
        fail_pipeline(state, :missing_rules, "No rule matching '#{current_invocation}'")
      {:error, {:denied, rule}} ->
        why = "You will need the '#{rule.permission_selector.perms.value}' permission to run this command."
        send_denied(current_invocation, why, state)
        fail_pipeline(state, :permission_denied, "User #{state.request["sender"]["handle"]} denied access to '#{current_invocation}'")
      {:error, msg} ->
        # TODO: what is this error case?
        send_error(msg, state)
        fail_pipeline(state, :binding_error, "Error preparing to execute command pipeline '#{state.request["text"]}': #{msg}")
      error ->
        {:error, msg} = error
        send_error(msg, state)
        fail_pipeline(state, :option_interpreter_error, "Error parsing options: #{inspect error}")
    end
  end
  def plan_next_invocation(:timeout, %__MODULE__{invocations: [], output: []}=state),
    do: respond(%{state | output: [{"Pipeline executed successfully, but no output was returned", nil}]})
  def plan_next_invocation(:timeout, %__MODULE__{invocations: []}=state),
    do: respond(state)

  def execute_plan(:timeout, %__MODULE__{plans: [current_plan|remaining_plans], request: request, user: user}=state) do
    bundle = current_plan.command.bundle
    name   = current_plan.command.name

    if bundle.enabled do
      case Cog.Relay.Relays.pick_one(bundle.name) do
        nil ->
          msg = "No Cog Relays supporting the `#{bundle.name}` bundle are currently online"
          send_error(msg, state)
          fail_pipeline(state, :no_relays, msg)
        relay ->
          topic = "/bot/commands/#{relay}/#{bundle.name}/#{name}"
          reply_to_topic = "#{state.topic}/reply"
          req = request_for_plan(current_plan, request, user, reply_to_topic)
          updated_state =  %{state | current_plan: current_plan, plans: remaining_plans}

          dispatch_event(updated_state, relay)
          Connection.publish(updated_state.mq_conn, Spanner.Command.Request.encode!(req), routed_by: topic)

          {:next_state, :wait_for_command, updated_state, @command_timeout}
      end
    else
      msg = "The #{inspect(bundle.name)} bundle is currently disabled"
      send_error(msg, state)
      fail_pipeline(state, :no_relays, msg)
    end
  end
  def execute_plan(:timeout, %__MODULE__{plans: []}=state),
    do: {:next_state, :plan_next_invocation, state, 0}

  def wait_for_command(:timeout, state) do
    send_timeout(state)
    fail_pipeline(state, :timeout, "Timed out waiting on #{state.current_plan.command} to reply")
  end

  def handle_info({:publish, topic, message}, :wait_for_command, state) do
    reply_topic = "#{state.topic}/reply" # TODO: bake this into state for easier pattern-matching?
    case topic do
      ^reply_topic ->
        payload = Poison.decode!(message)
        resp = Spanner.Command.Response.decode!(payload)
        case resp.status do
          "error" ->
            send_error(resp.status_message || resp.body["message"], state)
            fail_pipeline(state, :command_error, resp.status_message || resp.body["message"])
          "ok" ->
            collected_output = case resp.body do
                                 nil ->
                                   # If there wasn't any output,
                                   # there's nothing to collect
                                   state.output
                                 body ->
                                   state.output ++ Enum.map(List.wrap(body),
                                                            &store_with_template(&1, resp.template))
                                   # body may be a map or a list
                                   # of maps; if the latter, we
                                   # want to accumulate it into
                                   # one flat list
                               end
            {:next_state, :execute_plan, %{state | output: collected_output}, 0}
        end
      _ ->
        {:next_state, :wait_for_command, state}
    end
  end
  def handle_info(_, state_name, state),
    do: {:next_state, state_name, state}

  def handle_event(_event, state_name, state),
    do: {:next_state, state_name, state}

  def handle_sync_event(_event, _from, state_name, state),
    do: {:reply, :ignored, state_name, state}

  def code_change(_old_vsn, state_name, state, _extra),
    do: {:ok, state_name, state}

  def terminate(_reason, _state_name, %__MODULE__{error_type: nil}=state),
    do: success_event(state)
  def terminate(_reason, _state_name, state),
    do: failure_event(state)

  ########################################################################
  # Private functions

  ########################################################################
  # Redirection Resolution Functions

  # Returns {:ok, {adapter, room}} or {:error, invalid_redirect}
  defp lookup_room("me", state) do
    user_id = state.request["sender"]["id"]
    adapter = originating_adapter(state)
    case adapter.lookup_direct_room(user_id: user_id) do
      {:ok, direct_chat} ->
        {:ok, {state.request["adapter"], direct_chat}}
      error ->
        Logger.error("Error resolving redirect 'me' with adapter #{adapter}: #{inspect error}")
        {:error, "me"}
    end
  end
  defp lookup_room("here", state),
    do: {:ok, {state.request["adapter"], state.request["room"]}}
  defp lookup_room(redir, state) do
    {adapter, destination} = adapter_destination(redir, state)
    case adapter.lookup_room(destination) do
      {:ok, room} ->
        if adapter.room_writeable?(id: room.id) == true do
          {:ok, {adapter.name, room}}
        else
          {:error, {:not_a_member, redir}}
        end
      {:error, reason} ->
        Logger.error("Error resolving redirect '#{redir}' with adapter #{adapter}: #{inspect reason}")
        {:error, {reason, redir}}
    end
  end

  # Redirect destinations may be targeted to an adapter different from
  # where they originated from.
  #
  # Destinations prefixed with "chat://" will be routed through the
  # active chat adapter module. Anything else will be routed through
  # the adapter that initially serviced the request.
  defp adapter_destination("chat://" <> destination, _state) do
    {:ok, adapter} = Cog.adapter_module
    {adapter, destination}
  end
  defp adapter_destination(destination, state),
    do: {originating_adapter(state), destination}

  # Return the adapter module that initially handled the
  # request. Won't always be the chat adapter!
  defp originating_adapter(state),
    do: String.to_existing_atom(state.request["module"])

  # `errors` is a keyword list of [reason: name] for all bad redirect
  # destinations that were found. `name` is the value as originally
  # typed by the user.
  defp redirection_error_message(errors) do
    main_message = """

    No commands were executed because the following redirects are invalid:

    #{errors |> Keyword.values |> Enum.join(", ")}
    """

    not_a_member = Keyword.get_values(errors, :not_a_member)
    not_a_member_message = unless Enum.empty?(not_a_member) do
    """

    Additionally, the bot must be invited to these rooms before it can
    redirect to them:

    #{Enum.join(not_a_member, ", ")}
    """
    end

    # TODO: This is where I'd like to have error templates, so we can
    # be specific about recommending the conventions the user use to
    # refer to users and rooms
    ambiguous = Keyword.get_values(errors, :ambiguous)
    ambiguous_message = unless Enum.empty?(ambiguous) do
    """

    The following redirects are ambiguous; please refer to users and
    rooms according to the conventions of your chat provider
    (e.g. `@user`, `#room`):

    #{Enum.join(ambiguous, ", ")}
    """
    end

    # assemble final message
    message_fragments = [main_message,
                         not_a_member_message,
                         ambiguous_message]
    message_fragments
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
  end

  ########################################################################
  # Response Rendering Functions

  # TODO: remove bundle and room from command resp so commands can't excape their bundle.

  # Given pipeline output, apply templating as appropriate for each
  # adapter/destination it is to be sent to, and send it to each.
  defp respond(%__MODULE__{}=state) do
    output = state.output
    command = state.current_plan.command
    destinations = state.destinations
    adapters = Map.keys(destinations)
    rendered = render_for_adapters(output, command, adapters)

    case rendered do
      {:error, {error, template, adapter}} ->
        msg = "There was an error rendering the template '#{template}' for the adapter '#{adapter}': #{inspect error}"
        send_error(msg, state)
        fail_pipeline(state, :template_rendering_error, "Error rendering template '#{template}' for '#{adapter}': #{inspect error}")
      messages ->
        messages
        |> consolidate_by_adapter(destinations)
        |> Enum.each(fn({msg, adapter, destination}) ->
          publish_response(msg, destination, adapter, state)
        end)

        {:stop, :shutdown, state}
    end
  end

  # Return a map of adapter -> rendered message
  @spec render_for_adapters(List.t, %Cog.Models.Command{}, [adapter_name]) ::
                           %{adapter_name => String.t} |
                           {:error, {term, term, term}} # {error, template, adapter}
  defp render_for_adapters(data, command, adapters) do
    Enum.reduce_while(adapters, %{}, fn(adapter, acc) ->
      case render_templates(data, command, adapter) do
        {:error, _}=error ->
          {:halt, error}
        message ->
          {:cont, Map.put(acc, adapter, message)}
      end
    end)
  end

  # For a specific adapter, render each output, concatenating all
  # results into a single response string
  defp render_templates(command_output, command, adapter) do
    rendered_templates = Enum.reduce_while(command_output, [], fn({data, template}, acc) ->
      try do
        rendered_template = render_template(command, adapter, template, data)
        {:cont, [rendered_template | acc]}
      rescue
        error ->
          {:halt, {:error, {error, template, adapter}}}
      end
    end)

    case rendered_templates do
      {:error, data} ->
        {:error, data}
      messages ->
        Enum.reverse(messages)
        |> Enum.join("\n")
    end
  end

  # Render a single output
  defp render_template(command, adapter, nil, context),
    do: render_template(command, adapter, default_template(context), context)
  defp render_template(command, adapter, template, context) do
    # If `TemplateCache.lookup/3` returns nil instead of a function,
    # we know that the adapter doesn't have a template with the given
    # name. In this case, we can fall back to no template and run
    # through render_template again to pick up a default
    #
    # This is *NOT* a long-term solution.
    case TemplateCache.lookup(command.bundle.id, adapter, template) do
      fun when is_function(fun) ->
        fun.(context)
      nil ->
        Logger.warn("The template `#{template}` was not found for adapter `#{adapter}` in bundle `#{command.bundle.name}`; falling back to the default")
        render_template(command, adapter, nil, context)
    end
  end

  defp default_template(%{"body" => _}),                  do: "text"
  defp default_template(context) when is_binary(context), do: "text"
  defp default_template(context) when is_map(context),    do: "json"
  defp default_template(_),                               do: "raw"

  # make a list of {msg, adapter, dest}... slightly easier to process
  # in the end this way.
  @spec consolidate_by_adapter(%{adapter_name => String.t},
                               %{adapter_name => [redirect_destination]}) :: [{String.t, adapter_name, redirect_destination}]
  defp consolidate_by_adapter(adapter_msg, adapter_dest) do
    Enum.flat_map(adapter_dest, fn({adapter, dests}) ->
      Enum.map(dests, &({Map.fetch!(adapter_msg, adapter), adapter, &1}))
    end)
  end

  defp publish_response(message, room, adapter, state) do
    response = %{response: message,
                 id: state.id,
                 room: room}
    {:ok, adapter_mod} = Cog.adapter_module(adapter)
    reply_topic = adapter_mod.reply_topic
    Connection.publish(state.mq_conn, response, routed_by: reply_topic)
  end

  ########################################################################
  # Event Logging Functions

  # Shorthand for ending a pipeline with the appropriate error message
  #
  # There isn't a corresponding `succeed_pipeline` because all it
  # would return is `{:stop, :shutdown, state}`
  defp fail_pipeline(state, error, message),
    do: {:stop, :shutdown, %{state | error_type: error, error_message: message}}

  defp initialization_event(%__MODULE__{id: id, request: request,
                                        user: user}) do
    PipelineEvent.initialized(id, request["text"], request["adapter"],
                              user.username, request["sender"]["handle"])
    |> Probe.notify
  end

  defp dispatch_event(%__MODULE__{id: id, current_plan: plan}=state, relay) do
    PipelineEvent.dispatched(id, elapsed(state),
                             plan.invocation_text,
                             relay, plan.cog_env)
    |> Probe.notify
  end

  defp success_event(%__MODULE__{id: id, output: output}=state) do
    PipelineEvent.succeeded(id, elapsed(state), strip_templates(output))
    |> Probe.notify
  end

  defp failure_event(%__MODULE__{id: id}=state) do
    PipelineEvent.failed(id, elapsed(state), state.error_type, state.error_message)
    |> Probe.notify
  end

  # Return elapsed microseconds from when the pipeline started
  defp elapsed(%__MODULE__{started: started}),
    do: :timer.now_diff(:os.timestamp(), started)

  ########################################################################
  # Unregistered User Functions

  defp alert_unregistered_user(state) do
    publish_response(unregistered_user_message(state.request),
                     state.request["room"],
                     state.request["adapter"],
                     state)
  end

  defp unregistered_user_message(request) do
    adapter = String.to_existing_atom(request["module"])
    handle = request["sender"]["handle"]
    mention_name = adapter.mention_name(handle)
    display_name = adapter.display_name()
    user_creators = user_creator_handles(request)

    # If no users that can help have chat handles registered (e.g.,
    # the system was just bootstrapped and only the bootstrap
    # administrator is wired up permission-wise yet), we'll output a
    # basic message to ask for help.
    #
    # On the other hand, if there are people that can help that have
    # chat presences, we'll further add their names to the message, so
    # the user will some real people to ask
    #
    # I want error templates!
    call_to_action = case user_creators do
                       [] ->
                         "You'll need to ask a Cog administrator to fix this situation and to register your #{display_name} handle."
                       _ ->
                         "You'll need to ask a Cog administrator to fix this situation and to register your #{display_name} handle; the following users can help you right here in chat: #{Enum.join(user_creators, ", ")} ."
                     end
    # Yes, that space between the last mention and the period is
    # significant, at least for Slack; it won't format the mention as
    # a mention otherwise, because periods are allowed in their handles.

     """
     #{mention_name}: I'm sorry, but either I don't have a Cog account for you, or your #{display_name} chat handle has not been registered. Currently, only registered users can interact with me.

     #{call_to_action}
     """
  end

  # Returns a list of adapter-appropriate "mention names" of all Cog
  # users with registered handles for the adapter that currently have
  # the permissions required to create and manipulate new Cog user
  # accounts.
  #
  # The intention is to create a list of people that can assist
  # immediately in-chat when unregistered users attempt to interact
  # with Cog. Not every Cog user with these permissions will
  # necessarily have a chat handle registered for the chat provider
  # being used (most notably, the bootstrap admin user).
  defp user_creator_handles(request) do
    adapter = request["adapter"]
    adapter_module = String.to_existing_atom(request["module"])

    "operable:manage_users"
    |> Cog.Queries.Permission.from_full_name
    |> Cog.Repo.one!
    |> Cog.Queries.User.with_permission
    |> Cog.Queries.User.for_chat_provider(adapter)
    |> Cog.Repo.all
    |> Enum.flat_map(&(&1.chat_handles))
    |> Enum.map(&(adapter_module.mention_name(&1.handle)))
    |> Enum.sort
  end

  ########################################################################
  # Context Manipulation Functions

  # Each command in a pipeline has access to a "Cog Env", which is the
  # accumulated output of the execution of the pipeline thus far. This
  # is used as a binding context, as well as an input source for the
  # commands.
  #
  # The first command in a pipeline is different, though, as there is
  # no previous input. However, pipelines triggered by external events
  # (e.g., webhooks) can set the initial context to be, e.g., the body
  # of the HTTP request that triggered the pipeline.
  #
  # In the absence of an explicit initial context, a single empty map
  # is used. This provides an empty binding context for the first
  # command, preventing the use of unbound variables in the first
  # invocation of a pipeline. (For external-event initiated pipelines
  # with initial contexts, there can be variables in the first
  # invocation).
  #
  # In general, chat-adapter initiated pipelines will not be supplied
  # with an initial context.
  defp create_initial_context(request) do
    context = request
    |> Map.get("initial_context", [%{}])
    |> List.wrap

    if Enum.all?(context, &is_map/1) do
      {:ok, Enum.map(context, &store_with_template(&1, nil))}
    else
      :error
    end
  end

  # We need to track command output plus the specified template (if
  # any) needed to render it.
  #
  # See remove_templates/1 for inverse
  defp store_with_template(data, template),
    do: {data, template}

  # Templates only really matter at the very end of a pipeline; when
  # manipulating binding contexts inside the pipeline, we can safely
  # ignore them.
  #
  # See store_with_template/2 for inverse
  defp remove_template({data, _template}),
    do: data

  defp strip_templates(accumulated_output),
    do: Enum.map(accumulated_output, &remove_template/1)

  ########################################################################
  # Error Handling Functions

  defp send_error(error, state) when is_binary(error),
    do: send_reply("Whoops! An error occurred. #{error}", state)
  defp send_error(error, state) do
    Logger.warn("The error message #{inspect error} should be in string format for displaying to the user")
    send_reply("Whoops! An error occurred. #{inspect error}", state)
  end

  defp send_timeout(state) do
    command = state.current_plan.command
    send_reply("Hmmm. The #{command} command timed out.", state)
  end

  defp send_denied(which, why, state),
    do: send_reply("Sorry, you aren't allowed to execute '#{which}' :(\n #{why}", state)

  defp send_reply(message, state) do
    request = state.request

    message = if request["room"]["name"] != "direct" do
      "@#{request["sender"]["handle"]} " <> message
    else
      message
    end
    publish_response(message,
                     request["room"],
                     request["adapter"], # TODO: respect redirects?
                     state)
  end

  ########################################################################
  # Miscellaneous Functions

  defp request_for_plan(plan, request, user, reply_to) do
    # TODO: stuffing the provider into requestor here is a bit
    # code-smelly; investigate and fix
    provider  = request["adapter"]
    requestor = request["sender"] |> Map.put_new("provider", provider)
    room      = request["room"]
    user      = Cog.Models.EctoJson.render(user)

    %Spanner.Command.Request{command: Cog.Models.Command.full_name(plan.command),
                             options: plan.options,
                             args: plan.args,
                             cog_env: plan.cog_env,
                             requestor: requestor,
                             user: user,
                             room: room,
                             reply_to: reply_to}
  end

  defp sanitize_request(request) do
    prefix = Application.get_env(:cog, :command_prefix, "!")
    # Strip off command prefix before parsing
    text = Regex.replace(~r/^#{prefix}/, request["text"], "")
    # Replace '&amp;' with '&' (thanks Slack!)
    text = Regex.replace(~r/&amp;/, text, "&")
    # Replace unicode long dash with '--' to reverse OS X's replacement via the
    # "Smart Dashes" substitution, which is enabled by default
    text = Regex.replace(~r/—/, text, "--")
    # Replace unicode quotes with '"' to reverse OS X's replacement via the
    # "Smart Quotes" substitution, which is enabled by default
    text = Regex.replace(~r/“|”/, text, "\"")
    text = Regex.replace(~r/‘|’/, text, "'")
    # Decode Html Entities
    text = HtmlEntities.decode(text)
    # Update request with sanitized input
    Map.put(request, "text", text)
  end

  def fetch_user_from_request(request) do
    adapter   = request["adapter"]
    sender_id = request["sender"]["id"]

    user = Queries.User.for_chat_provider_user_id(sender_id, adapter)
    |> Repo.one

    case user do
      nil ->
        {:error, :not_found}
      user ->
        {:ok, user}
    end
  end
end
