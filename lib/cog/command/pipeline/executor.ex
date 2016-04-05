defmodule Cog.Command.Pipeline.Executor do

  alias Carrier.Messaging.Connection
  alias Cog.Command.CommandResolver
  alias Cog.Command.PermissionsCache
  alias Cog.Events.PipelineEvent
  alias Cog.Queries
  alias Cog.Repo
  alias Cog.Template
  alias Piper.Command.Ast
  alias Piper.Command.Parser
  alias Piper.Command.ParserOptions
  alias Cog.Command.Pipeline.Destination
  alias Cog.Command.Pipeline.Plan

  @type adapter_name :: String.t

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
    destinations: [Destination.t],
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
            alert_unregistered_user(%__MODULE__{id: id, mq_conn: conn, request: request})
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
        case Destination.process(Ast.Pipeline.redirect_targets(pipeline),
                                 state.request["sender"],
                                 state.request["room"],
                                 originating_adapter(state)) do
          {:ok, destinations} ->
            {:next_state,
             :plan_next_invocation, %{state |
                                      destinations: destinations,
                                      invocations: Enum.to_list(pipeline)}, 0}
          {:error, invalid} ->
            fail_pipeline_with_error({:redirect_error, invalid}, state)
        end
      {:error, msg} ->
        fail_pipeline_with_error({:parse_error, msg}, state)
    end
  end

  def plan_next_invocation(:timeout, %__MODULE__{invocations: [current_invocation|remaining],
                                                 output: previous_output,
                                                 user_permissions: permissions}=state) do
    state = %{state | current_plan: nil}
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
      {:error, {:missing_key, _}=error} ->
        fail_pipeline_with_error({:binding_error, error}, state)
      {:error, :no_rule} ->
        fail_pipeline_with_error({:no_rule, current_invocation}, state)
      {:error, {:denied, _}=error} ->
        fail_pipeline_with_error(error, state)
      {:error, msg} when is_binary(msg) ->
        # These are error strings that are generated from within the
        # binding infrastructure... should probably pull those strings
        # up to here instead
        fail_pipeline_with_error({:binding_error, msg}, state)
    end
  end
  def plan_next_invocation(:timeout, %__MODULE__{invocations: [], output: []}=state),
    do: succeed_with_response(%{state | output: [{"Pipeline executed successfully, but no output was returned", nil}]})
  def plan_next_invocation(:timeout, %__MODULE__{invocations: []}=state),
    do: succeed_with_response(state)

  def execute_plan(:timeout, %__MODULE__{plans: [current_plan|remaining_plans], request: request, user: user}=state) do
    bundle = current_plan.command.bundle
    name   = current_plan.command.name

    if bundle.enabled do
      case Cog.Relay.Relays.pick_one(bundle.name) do
        nil ->
          fail_pipeline_with_error({:no_relays, bundle}, state)
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
      fail_pipeline_with_error({:disabled_bundle, bundle}, state)
    end
  end
  def execute_plan(:timeout, %__MODULE__{plans: []}=state),
    do: {:next_state, :plan_next_invocation, state, 0}

  def wait_for_command(:timeout, state),
    do: fail_pipeline_with_error({:timeout, state.current_plan.command}, state)

  def handle_info({:publish, topic, message}, :wait_for_command, state) do
    reply_topic = "#{state.topic}/reply" # TODO: bake this into state for easier pattern-matching?
    case topic do
      ^reply_topic ->
        payload = Poison.decode!(message)
        resp = Spanner.Command.Response.decode!(payload)
        case resp.status do
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
          "error" ->
            fail_pipeline_with_error({:command_error, resp}, state)
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
    bundle = state.current_plan.command.bundle
    by_output_level = Enum.group_by(state.destinations, &(&1.output_level))

    # Render full output first
    full = Map.get(by_output_level, :full, [])
    adapters = full |> Enum.map(&(&1.adapter)) |> Enum.uniq

    case render_for_adapters(adapters, bundle, output) do
      {:error, {error, template, adapter}} ->
        # TODO: need to send error, THEN fail at the end, since we may
        # need to do it for status-only destinations
        fail_pipeline_with_error({:template_rendering_error, {error, template, adapter}}, state)
      messages ->
        Enum.each(full, fn(dest) ->
          msg = Map.fetch!(messages, dest.adapter)
          publish_response(msg, dest.room, dest.adapter, state)
        end)
    end

    # Now for status only
    # No rendering, just status map
    by_output_level
    |> Map.get(:status_only, [])
    |> Enum.each(fn(dest) ->
      publish_response(%{status: "ok"}, dest.room, dest.adapter, state)
    end)

  end

  defp succeed_with_response(state) do
    respond(state)
    # TODO: what happens if we fail due to a template error?
    {:stop, :shutdown, state}
  end


  # Return a map of adapter -> rendered message
  @spec render_for_adapters([adapter_name], %Cog.Models.Bundle{}, List.t) ::
                           %{adapter_name => String.t} |
                           {:error, {term, term, term}} # {error, template, adapter}
  defp render_for_adapters(adapters, bundle, output) do
    Enum.reduce_while(adapters, %{}, fn(adapter, acc) ->
      case render_templates(adapter, bundle, output) do
        {:error, _}=error ->
          {:halt, error}
        message ->
          {:cont, Map.put(acc, adapter, message)}
      end
    end)
  end

  # For a specific adapter, render each output, concatenating all
  # results into a single response string
  defp render_templates(adapter, bundle, output) do
    rendered_templates = Enum.reduce_while(output, [], fn({context, template}, acc) ->
      case render_template(adapter, bundle, template, context) do
        {:ok, result} ->
          {:cont, [result|acc]}
        {:error, error} ->
          {:halt, {:error, {error, template, adapter}}}
      end
    end)

    case rendered_templates do
      {:error, error} ->
        {:error, error}
      messages ->
        messages
        |> Enum.reverse
        |> Enum.join("\n")
    end
  end

  defp render_template(adapter, bundle, template, context) do
    case Template.render(adapter, bundle.id, template, context) do
      {:ok, output} ->
        {:ok, output}
      {:error, :template_not_found} ->
        Logger.warn("The template `#{template}` was not found for adapter `#{adapter}` in bundle `#{bundle.name}`; falling back to the json template")
        Template.render(adapter, nil, "json", context)
      {:error, error} ->
        {:error, error}
    end
  end

  defp publish_response(message, room, adapter, state) do
    response = %{response: message,
                 id: state.id,
                 room: room}
    # Remember, it might not be a *chat* adapter we're responding to
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

  # TODO: needs to be different for non-chat adapters
  defp unregistered_user_message(request) do
    adapter = String.to_existing_atom(request["module"])
    handle = request["sender"]["handle"]

    context = %{
      handle: handle,
      mention_name: adapter.mention_name(handle),
      display_name: adapter.display_name(),
      user_creators: user_creator_handles(request)
    }

    {:ok, output} = Template.render("any", nil, "unregistered_user", context)
    output
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
    |> Map.fetch!("initial_context")
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

  # Create a standard error message for pipeline-related
  # errors. Eventually this will be templated.
  defp user_error(error, state) do
    id = state.id
    started = Cog.Events.Util.ts_iso8601_utc(state.started)
    initiator = sender_name(state)
    pipeline_text = state.request["text"]
    error_message = format_user_error(error, state)
    failing = case state.current_plan do
                %Plan{}=plan ->
                  # If it failed during execution, there will be a
                  # plan we can point to
                  plan
                nil ->
                  # If it happened during planning, there will be an
                  # invocation to show
                  case state.invocations do
                    [current|_] ->
                      current
                    _ ->
                      # Otherwise, it happened sometime during
                      # parsing, and we already have the full pipeline
                      # text to show
                      nil
                  end
              end

    # All error messages start with this prologue
    base = """
    An error has occurred.

    At `#{started}`, #{initiator} initiated the following pipeline, assigned the unique ID `#{id}`:

        `#{pipeline_text}`

    """

    # If the failure happened during planning or execution, we'll have
    # a bit more information to show
    command_text = case failing do
                     %Ast.Invocation{} ->
                     """
                     The pipeline failed planning the invocation:

                         `#{failing}`
                     """
                     %Plan{} ->
                     """
                     The pipeline failed executing the command:

                         `#{failing.invocation_text}`

                     """
                     nil ->
                       nil
                   end

    # Finally, the text of the specific error that occurred
    error_text = """
    The specific error was:

        #{error_message}

    """

    [base, command_text, error_text]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
  end

  # Turn an error tuple into a textual message intended for chat users
  defp format_user_error({:parse_error, msg}, _state) when is_binary(msg),
    do: "Whoops! An error occurred. " <> msg
  defp format_user_error({:redirect_error, invalid}, _state),
    do: "Whoops! An error occurred. " <> redirection_error_message(invalid)
  defp format_user_error({:binding_error, {:missing_key, var}}, _state),
    do: "I can't find the variable '$#{var}'."
  defp format_user_error({:binding_error, msg}, _state) when is_binary(msg),
    do: "Whoops! An error occurred. " <> msg
  defp format_user_error({:no_rule, current_invocation}, _state),
    do: "No rules match the supplied invocation of '#{current_invocation}'. Check your args and options, then confirm that the proper rules are in place."
  defp format_user_error({:denied, %Piper.Permissions.Ast.Rule{}=rule}, %__MODULE__{invocations: [current_invocation|_]}),
    do: "Sorry, you aren't allowed to execute '#{current_invocation}' :(\n You will need the '#{rule.permission_selector.perms.value}' permission to run this command."
  defp format_user_error({:no_relays, %Cog.Models.Bundle{name: name}}, _state),
    do: "Whoops! An error occurred. No Cog Relays supporting the `#{name}` bundle are currently online"
  defp format_user_error({:disabled_bundle, %Cog.Models.Bundle{name: name}}, _state),
    do: "Whoops! An error occurred. The #{name} bundle is currently disabled"
  defp format_user_error({:timeout, %Cog.Models.Command{}=command}, _state) do
    name = Cog.Models.Command.full_name(command)
    "The #{name} command timed out"
  end
  defp format_user_error({:template_rendering_error, {error, template, adapter}}, _state),
    do: "Whoops! An error occurred. There was an error rendering the template '#{template}' for the adapter '#{adapter}': #{inspect error}"
  defp format_user_error({:command_error, response}, _state),
    do: "Whoops! An error occurred. " <> (response.status_message || response.body["message"])

  # Turn an error tuple into a message intended for the audit log
  defp format_audit_message({:parse_error, msg}, state) when is_binary(msg),
    do: "Error parsing command pipeline '#{state.request["text"]}': #{msg}"
  defp format_audit_message({:redirect_error, invalid}, _state),
    do: "Invalid redirects were specified: #{inspect invalid}"
  defp format_audit_message({:binding_error, {:missing_key, var}}, state),
    do: "Error preparing to execute command pipeline '#{state.request["text"]}': Unknown variable '#{var}'"
  defp format_audit_message({:binding_error, msg}, state) when is_binary(msg) do
    # TODO: Pretty sure this is not what we want, ultimately... this
    # is coming from plan_next_invocation, not some top-level place
    "Error preparing to execute command pipeline '#{state.request["text"]}': #{msg}"
  end
  defp format_audit_message({:denied, _}, %__MODULE__{invocations: [current_invocation|_]}=state),
    do: "User #{state.request["sender"]["handle"]} denied access to '#{current_invocation}'"
  defp format_audit_message({:no_relays, bundle}, state),
    do: format_user_error({:no_relays, bundle}, state) # Uses same user message for now
  defp format_audit_message({:disabled_bundle, %Cog.Models.Bundle{name: name}}, _state),
    do: "The #{name} bundle is currently disabled"
  defp format_audit_message({:command_error, response}, _state),
    do: response.status_message || response.body["message"]
  defp format_audit_message({:template_rendering_error, {error, template, adapter}}, _state),
    do: "Error rendering template '#{template}' for '#{adapter}': #{inspect error}"
  defp format_audit_message({:timeout, %Cog.Models.Command{}=command}, _state) do
    name = Cog.Models.Command.full_name(command)
    "Timed out waiting on #{name} to reply"
  end
  defp format_audit_message({:no_rule, current_invocation}, _state),
    do: "No rule matching '#{current_invocation}'"

  # Catch-all function that sends an error message back to the user,
  # emits a pipeline failure audit event, and terminates the pipeline.
  defp fail_pipeline_with_error({reason, _detail}=error, state) do
    user_message = user_error(error, state)
    publish_response(user_message,
                     state.request["room"],
                     state.request["adapter"],
                     state)

    audit_message = format_audit_message(error, state)
    fail_pipeline(state, reason, audit_message)
  end

  defp sender_name(state) do
    adapter = originating_adapter(state)
    if adapter.chat_adapter? do
      adapter.mention_name(state.request["sender"]["handle"])
    else
      state.request["sender"]["id"]
    end
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

    Map.update!(request, "text", fn text ->
      text
      |> String.replace(~r/^#{prefix}/, "") # Remove command prefix
      |> String.replace(~r/“|”/, "\"")      # Replace OS X's smart quotes and dashes with ascii equivalent
      |> String.replace(~r/‘|’/, "'")
      |> String.replace(~r/—/, "--")
      |> HtmlEntities.decode                # Decode html entities
    end)
  end

  def fetch_user_from_request(request) do
    adapter_module = request["module"] |> String.to_existing_atom

    if adapter_module.chat_adapter? do
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
    else
      cog_name = request["sender"]["id"]
      case Repo.get_by(Cog.Models.User, username: cog_name) do
        %Cog.Models.User{}=user ->
          {:ok, user}
        nil ->
          {:error, :not_found}
      end
    end
  end
end
