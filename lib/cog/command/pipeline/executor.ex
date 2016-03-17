defmodule Cog.Command.Pipeline.Executor do

  @typedoc """
  Custom State for executor

  ## Fields

  * `:id` - Generated id for the pipeline executor.
  * `:topic` - The topic that the executor listens on.
  * `:started` - Timestamp for the start of the pipeline.
  * `:mq_conn` - The message queue connection.
  * `:request` - The original request from the adapter.
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
    destinations: List.t,
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
    destinations: [],
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
  alias Cog.Command.Pipeline.Executor.Helpers
  alias Cog.Command.UserPermissionsCache
  alias Cog.Events.PipelineEvent
  alias Cog.TemplateCache
  alias Piper.Command.Ast
  alias Piper.Command.Parser
  alias Piper.Command.ParserOptions

  use Adz

  # Provide an empty map for initial binding. The `nil` is for a
  # template, and just to maintain the proper "shape" of the data
  @seed_context [{%{}, nil}]

  def start_link(request),
    do: :gen_fsm.start_link(__MODULE__, [request], [])

  def init([request]) when is_map(request) do
    request = sanitize_request(request)
    {:ok, conn} = Connection.connect()
    id = UUID.uuid4(:hex)
    topic = "/bot/pipelines/#{id}"

    Connection.subscribe(conn, topic <> "/+")

    adapter = request["adapter"]
    handle = request["sender"]["handle"]
    # We resolve users and permissions at this stage so that we can
    # include the Cog user (and not just their adapter-specific
    # handle) in event logs (and also to prevent us doing unnecessary
    # work for users that don't have Cog accounts)
    case UserPermissionsCache.fetch(username: handle, adapter: adapter) do
      {:ok, {user, perms}} ->
        loop_data = %__MODULE__{id: id, topic: topic, request: request,
                                mq_conn: conn,
                                user: user,
                                user_permissions: perms,
                                output: @seed_context,
                                started: :os.timestamp()}
        initialization_event(loop_data)
        {:ok, :parse, loop_data, 0}
      {:error, :not_found} ->
        alert_unregistered_user(%__MODULE__{mq_conn: conn, request: request})
        :ignore
    end
  end

  def parse(:timeout, state) do
    options = %ParserOptions{resolver: CommandResolver.command_resolver_fn(state.user)}
    case Parser.scan_and_parse(state.request["text"], options) do
      {:ok, %Ast.Pipeline{}=pipeline} ->
        {:next_state, :resolve_destinations, %{state |
                                               destinations: Ast.Pipeline.redirect_targets(pipeline),
                                               invocations: Enum.to_list(pipeline)}, 0}
      {:error, msg} ->
        Helpers.send_reply(msg, state.request, state.mq_conn)
        fail_pipeline(state, :parse_error, "Error parsing command pipeline '#{state.request["text"]}': #{msg}")
    end
  end

  def resolve_destinations(:timeout, %__MODULE__{destinations: destinations}=state) do
    redirs = case destinations do
               [] ->
                 # If no redirects were given, we default to the
                 # current room; this keeps things uniform later on.
                 {:ok, [state.request["room"]]}
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
        {:next_state, :plan_next_invocation, %{state | destinations: destinations}, 0}
      {:error, invalid} ->
        # TODO: having a really good error message for this would
        # entail better differentiating the reasons for specific
        # failures: room not found, not a member of a room, etc. (You
        # could even extend this to things like "inactive user",
        # "archived room", and so on.) Something multi-line would be
        # best, but formatting ends up being weird with our current
        # helpers.
        #
        # A long-term solution probably involves some sort of error
        # templating, which we've discussed. The current
        # implementation at least gives the user some actionable (if
        # not pretty) feedback.
        not_a_member = Keyword.get_values(invalid, :not_a_member)
        Helpers.send_error("No commands were executed because the following redirects are invalid: #{invalid |> Keyword.values |> Enum.join(", ")}#{unless Enum.empty?(not_a_member), do: ". Additionally, the bot must be invited to these rooms before it can redirect to them: #{Enum.join(not_a_member, ", ")}"}", state.request, state.mq_conn)
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
      {:error, {:not_found, var}} ->
        Helpers.send_reply("I can't find the variable '$#{var}'.", state.request, state.mq_conn)
        fail_pipeline(state, :binding_error, "Error preparing to execute command pipeline '#{state.request["text"]}': Unknown variable '#{var}'")
      {:error, :no_rule} ->
        why = "No rules match the supplied invocation of '#{current_invocation}'. Check your args and options, then confirm that the proper rules are in place."
        Helpers.send_denied(current_invocation, why, state.request, state.mq_conn)
        fail_pipeline(state, :missing_rules, "No rule matching '#{current_invocation}'")
      {:error, {:denied, rule}} ->
        why = "You will need the '#{rule.permission_selector.perms.value}' permission to run this command."
        Helpers.send_denied(current_invocation, why, state.request, state.mq_conn)
        fail_pipeline(state, :permission_denied, "User #{state.request["sender"]["handle"]} denied access to '#{current_invocation}'")
      {:error, msg} ->
        # TODO: what is this error case?
        Helpers.send_error(msg, state.request, state.mq_conn)
        fail_pipeline(state, :binding_error, "Error preparing to execute command pipeline '#{state.request["text"]}': #{msg}")
      error ->
        {:error, msg} = error
        Helpers.send_error(msg, state.request, state.mq_conn)
        fail_pipeline(state, :option_interpreter_error, "Error parsing options: #{inspect error}")
    end
  end
  def plan_next_invocation(:timeout, %__MODULE__{invocations: [], output: [], destinations: destinations}=state) do
    message = "Pipeline executed successfully, but no output was returned"
    adapter = state.request["adapter"]
    Enum.each(destinations, &publish_response(response_fn(message, adapter), &1, state))
    {:stop, :shutdown, %{state | output: []}}
  end
  def plan_next_invocation(:timeout, %__MODULE__{invocations: [], output: output, destinations: destinations}=state) do
    # No more invocations, but we've got data; run it through
    # templating and send it out to all the destinations
    command = state.current_plan.command
    adapter = state.request["adapter"]

    message = Enum.map_join(output, "\n", fn({data,template}) ->
      render_template(command, adapter, template, data)
    end)

    Enum.each(destinations, &publish_response(response_fn(message, adapter), &1, state))
    {:stop, :shutdown, state}
  end

  def execute_plan(:timeout, %__MODULE__{plans: [current_plan|remaining_plans], request: request}=state) do
    bundle = current_plan.command.bundle
    name   = current_plan.command.name

    if bundle.enabled do
      case Cog.Relay.Relays.pick_one(bundle.name) do
        nil ->
          msg = "No Cog Relays supporting the `#{bundle.name}` bundle are currently online"
          Helpers.send_error(msg, state.request, state.mq_conn)
          fail_pipeline(state, :no_relays, msg)
        relay ->
          topic = "/bot/commands/#{relay}/#{bundle.name}/#{name}"
          reply_to_topic = "#{state.topic}/reply"

          req = request_for_plan(current_plan,
                                       # TODO: Just send the request in?
                                       request["sender"],
                                       request["room"],
                                       request["adapter"],
                                       reply_to_topic)

          updated_state =  %{state | current_plan: current_plan, plans: remaining_plans}

          dispatch_event(updated_state, relay)

          Connection.publish(updated_state.mq_conn, Spanner.Command.Request.encode!(req), routed_by: topic)
          {:next_state, :wait_for_command, updated_state, @command_timeout}
      end
    else
      msg = "The `#{bundle}` bundle is currently disabled"
      Helpers.send_error(msg, state.request, state.mq_conn)
      fail_pipeline(state, :no_relays, msg)
    end
  end
  def execute_plan(:timeout, %__MODULE__{plans: []}=state),
    do: {:next_state, :plan_next_invocation, state, 0}

  def wait_for_command(:timeout, state) do
    Helpers.send_timeout(state.current_plan.command, state.request, state.mq_conn)
    fail_pipeline(state, :timeout, "Timed out waiting on #{state.current_plan.command} to reply")
  end

  def handle_info({:publish, topic, message}, :wait_for_command, state) do
    reply_topic = "#{state.topic}/reply" # TODO: bake this into state for easier pattern-matching?
    case topic do
      ^reply_topic ->
        case Carrier.CredentialManager.verify_signed_message(message) do
          {true, payload} ->
            resp = Spanner.Command.Response.decode!(payload)
            case resp.status do
              "error" ->
                Helpers.send_error(resp.status_message || resp.body["message"], state.request, state.mq_conn)
                fail_pipeline(state, :command_error, resp.status_message || resp.body["message"])
              "ok" ->
                collected_output = case resp.body do
                                     nil ->
                                       # If there wasn't any output,
                                       # there's nothing to collect
                                       state.output
                                     body ->
                                       state.output ++ Enum.map(List.wrap(body), &({&1, resp.template}))
                                       # body may be a map or a list
                                       # of maps; if the latter, we
                                       # want to accumulate it into
                                       # one flat list
                                   end
                {:next_state, :execute_plan, %{state | output: collected_output}, 0}
            end
          false ->
            fail_pipeline(state, :message_authenticity, "Message signature not verified! #{inspect message}")
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

  # Returns {:ok, room} or {:error, invalid_redirect}
  defp lookup_room("me", state) do
    user_id = state.request["sender"]["id"]
    adapter = String.to_existing_atom(state.request["module"])
    case adapter.lookup_direct_room(user_id: user_id) do
      {:ok, direct_chat} ->
        {:ok, direct_chat}
      error ->
        Logger.error("Error resolving redirect 'me' with adapter #{adapter}: #{inspect error}")
        {:error, "me"}
    end
  end
  defp lookup_room("here", state),
    do: {:ok, state.request["room"]}
  defp lookup_room(redir, state) do
    adapter = String.to_existing_atom(state.request["module"])
    case adapter.lookup_room(redir) do
      {:ok, room} ->
        if adapter.room_writeable?(id: room.id) == true do
          {:ok, room}
        else
          {:error, {:not_a_member, redir}}
        end
      {:error, reason} ->
        Logger.error("Error resolving redirect '#{redir}' with adapter #{adapter}: #{inspect reason}")
        {:error, {reason, redir}}
    end
  end

  ########################################################################
  # Response Rendering Functions

  # TODO: remove bundle and room from command resp so commands can't excape their bundle.

  # Create a function that accepts a room and generates an appropriate
  # response map. The template is rendered for the response once and
  # the result is embedded in the returned function.
  #
  # This enables us to render a template only once, regardless of how
  # many destinations we ultimately forward the response to.
  defp response_fn(message, adapter) when is_binary(message) do
    fn(room) ->
      %{response: message,
        room: room,
        adapter: adapter}
    end
  end

  defp publish_response(response_fn, room, state),
    do: Connection.publish(state.mq_conn, response_fn.(room), routed_by: state.request["reply"])

  defp default_template(%{"body" => _}),
    do: "text"
  defp default_template(context) when is_binary(context),
    do: "text"
  defp default_template(context) when is_map(context),
    do: "json"
  defp default_template(_),
    do: "raw"

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

  defp dispatch_event(%__MODULE__{id: id, current_plan: current_plan}=state, relay) do
    PipelineEvent.dispatched(id, elapsed(state), current_plan.invocation_text, relay)
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
    response_fn = response_fn(unregistered_user_message(state.request),
                              state.request["adapter"])
    publish_response(response_fn, state.request["room"], state)
  end

  defp unregistered_user_message(request) do
    adapter = String.to_existing_atom(request["module"])
    handle = request["sender"]["handle"]
    mention_name = adapter.mention_name(handle)
    display_name = adapter.display_name()
    user_creators = user_creators(request)

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
  defp user_creators(request) do
    adapter = request["adapter"]
    adapter_module = String.to_existing_atom(request["module"])

    "operable:manage_users"
    |> Cog.Queries.Permission.from_full_name
    |> Cog.Repo.one!
    |> Cog.Queries.User.with_permission
    |> Cog.Queries.User.with_chat_handle_for(adapter)
    |> Cog.Repo.all
    |> Enum.flat_map(&(&1.chat_handles))
    |> Enum.map(&(adapter_module.mention_name(&1.handle)))
    |> Enum.sort
  end

  ########################################################################
  # Miscellaneous Functions

  # When we accumulate output, we pair the response body with the
  # template in a tuple. To recover just the raw data again, we simply
  # strip the template and surrounding tuple
  defp strip_templates(accumulated_output),
    do: Enum.map(accumulated_output, fn({data, _template}) -> data end)

  defp request_for_plan(plan, requestor, room, provider, reply_to) do
    # TODO: stuffing the provider into requestor here is a bit
    # code-smelly; investigate and fix
    requestor = Map.put_new(requestor, "provider", provider)
    %Spanner.Command.Request{command: Cog.Models.Command.full_name(plan.command),
                             options: plan.options,
                             args: plan.args,
                             cog_env: plan.cog_env,
                             requestor: requestor,
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

end
