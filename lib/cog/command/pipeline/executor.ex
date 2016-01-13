defmodule Cog.Command.Pipeline.Executor do
  @moduledoc """
  The command executor, `#{inspect __MODULE__}` is responsible for parsing the
  command request and executing one or more commands. This is largely a
  "timeout=0" driven fsm with `:wait_for_connect` and `:wait_for_command` being
  triggered by messages over the mqtt bus.

  ## Execution order
  * :init
  * :wait_for_connect
  * :parse
  * :lookup_redirects
  * :bind
  * :get_options
  * :maybe_enforce
  * :check_permissions
  * :run_command
  * :waiting_for_command
  * end | :bind
  """

  @typedoc """
  Custom State for executor

  ## Fields

  * `:id` - Generated id for the pipeline executor.
  * `:topic` - The topic that the executor listens on.
  * `:started` - Timestamp for the start of the pipeline.
  * `:mq_conn` - The mqtt connection.
  * `:request` - The original request from the adapter.
  * `:scope` - The current scope for variable interpretation.
  * `:pipeline` - The parsed pipeline
  * `:redirects` - The resolved redirects, if any exist
  * `:current` - The current command invocation in the pipeline
    executor.
  * `:current_bound` - The current command invocation after binding to
    the scope.
  * `:remaining` - The remaining invocations in the pipeline.
  * `:input` - When commands return a list of results those results
    are added to an input buffer and the next command is executed once
    per item in the input buffer. Kind of an xargs style behavior by
    default.
  * `:output` - The accumulated output of commands executed with a
    list of results.
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
    request: Spanner.Command.Request,
    scope: Piper.Bind.Scope,
    pipeline: Piper.Ast.Pipeline,
    redirects: List.t,
    current: Piper.Ast.Invocation,
    current_bound: Piper.Ast.Invocation,
    remaining: List.t,
    input: List.t,
    output: List.t,
    error_type: atom(),
    error_message: String.t
  }

  defstruct [id: nil, topic: nil, mq_conn: nil, request: nil,
             scope: nil, pipeline: nil, redirects: [], current: nil,
             current_bound: nil, remaining: [], input: [], output: [],
             started: nil, error_type: nil, error_message: nil]

  @behaviour :gen_fsm

  # Timeout for commands once they are in the `run_command` state
  @command_timeout 60000

  alias Cog.Command.Pipeline.Executor.Helpers
  alias Cog.Command.OptionInterpreter
  alias Cog.Command.PermissionInterpreter
  alias Cog.Command.CommandCache
  alias Cog.Command.BundleResolver
  alias Cog.Models
  alias Cog.TemplateCache
  alias Piper.Command.Parser
  alias Piper.Command.Ast
  alias Piper.Command.Bindable
  alias Piper.Command.Bind

  alias Carrier.Messaging.Connection
  alias Cog.Events.PipelineEvent

  use Adz

  def start_link(request) do
    :gen_fsm.start_link(__MODULE__, [request], [])
  end

  @doc """
  `init` -> {:next_state, :wait_for_connect}

  Initializes the executor
  """
  def init([request]) when is_map(request) do
    request = sanitize_request(request)
    {:ok, conn} = Connection.connect()
    id = UUID.uuid4(:hex)
    topic = "/bot/pipelines/#{id}"

    Connection.subscribe(conn, topic <> "/+")

    loop_data = %__MODULE__{id: id, topic: topic, request: request,
                            mq_conn: conn,
                            scope: Bind.Scope.empty_scope(),
                            input: [], output: [],
                            started: :os.timestamp()}
    log_initialization(loop_data)

    {:ok, :parse, loop_data, 0}
  end

  @doc """
  `parse` -> {:stop, :shutdown} | {:next_state, :bind}

  After connecting the request string is parsed and an invocation
  (`%Piper.Ast.Invocation{}`) or a pipeline(`%Piper.Ast.Pipeline{}`) is added
  to `remaining` in the state.
  """
  def parse(:timeout, state) do
    case Parser.scan_and_parse(state.request["text"], command_resolver: &BundleResolver.find_bundle/1) do
      {:ok, %Ast.Invocation{}=invocation} ->
        {:next_state, :lookup_redirects, %{state | pipeline: %Ast.Pipeline{invocations: [invocation]}}, 0}
      {:ok, %Ast.Pipeline{}=pipeline} ->
        {:next_state, :lookup_redirects, %{state | pipeline: pipeline}, 0}
      {:error, msg}->
        Helpers.send_reply(msg, state.request, state.mq_conn)
        fail_pipeline(state, :parse_error, "Error parsing command pipeline '#{state.request["text"]}': #{msg}")
    end
  end

  @doc """
  `lookup_redirects` -> {:stop, :shutdown} | {:next_state, :prepare}

  Looks up redirects. Stops on invalid redirects
  """
  def lookup_redirects(:timeout, %__MODULE__{pipeline: pipeline}=state) do
    %Ast.Pipeline{invocations: invocations} = pipeline
    redirs = List.last(invocations)
    |> Map.get(:redirs)

    resolved_redirs = Enum.map(redirs, fn(redir) ->
      case lookup_room(redir, state) do
        {:ok, room} ->
          room
        {:error, _reason} ->
          Helpers.send_error("Invalid redirect `#{redir}`", state.request, state.mq_conn)
          :not_found
      end
    end)

    case Enum.member?(resolved_redirs, :not_found) do
      false ->
        prepare(%{state | redirects: resolved_redirs})
      true ->
        fail_pipeline(state, :redirect_error, "Invalid redirects were specified")
    end
  end

  @doc """
  `bind` -> {:next_state, :get_options}

  Binds the current invocation to the scope.
  """
  def bind(:timeout, %__MODULE__{current: current, scope: scope}=state) do
    {:ok, resolved_scope} = Bindable.resolve(current, scope)
    case Bindable.bind(current, resolved_scope) do
      {:error, msg} ->
        Helpers.send_reply(msg, state.request, state.mq_conn)
        fail_pipeline(state, :binding_error, "Error preparing to execute command pipeline '#{state.request["text"]}': #{msg}")
      {:ok, current_bound, bound_scope} ->
        {:next_state, :get_options, %{state | current_bound: current_bound, scope: bound_scope}, 0}
    end
  end

  @doc """
  `get_options` -> {:stop, :shutdown} | {:next_state, :check_permission}

  Runs the option interpreter on the current bound invocation.
  """
  def get_options(:timeout, %__MODULE__{current_bound: current_bound}=state) do
    case OptionInterpreter.initialize(current_bound, current_bound.args) do
      {:ok, options, args} ->
        current_bound = %{current_bound | options: options, args: args}
        {:next_state, :maybe_enforce, %{state | current_bound: current_bound}, 0}
      :not_found ->
        Helpers.send_idk(state.request, current_bound.command, state.mq_conn)
        fail_pipeline(state, :option_interpreter_error, "Command '#{current_bound.command}' not found")
      error ->
        {:error, msg} = error
        Helpers.send_error(msg, state.request, state.mq_conn)
        fail_pipeline(state, :option_interpreter_error, "Error parsing options: #{inspect error}")
    end
  end

  @doc """
  `maybe_enforce` -> {:next_state, :run_command} | {:next_state, :check_permission}

  If the command is enforced then the permission check is skipped and the command
  is executed.
  """
  def maybe_enforce(:timeout, %__MODULE__{current_bound: current_bound}=state) do
    {:ok, command} = CommandCache.fetch(current_bound)
    if command.enforcing do
      {:next_state, :check_permission, state, 0}
    else
      {:next_state, :run_command, state, 0}
    end
  end

  @doc """
  `check_permission` -> {:stop, :shutdown} | {:next_state, :run_command}

  Checks to see if the user has permission to execute the current command. We
  run check permissions here because this is the first time we have all the
  information available to determine if the user has the proper perms.
  """
  def check_permission(:timeout, %__MODULE__{current: current, current_bound: current_bound}=state) do
    case PermissionInterpreter.check(state.request["sender"]["handle"],
                                     state.request["adapter"], current_bound) do
      :ignore ->
        fail_pipeline(state, :user_not_found, "Ignoring message from unknown user #{state.request["sender"]["handle"]}")
      :allowed ->
        {:next_state, :run_command, state, 0}
      {:no_rule, _invoke} ->
        why = "No rules match the supplied invocation of '#{current}'. Check your args and options, then confirm that the proper rules are in place."
        Helpers.send_denied(current, why, state.request, state.mq_conn)
        fail_pipeline(state, :missing_rules, "No rule matching '#{current}'")
      {:denied, _invoke, rule} ->
        why = "You will need the '#{rule.permission_selector.perms.value}' permission to run this command."
        Helpers.send_denied(current, why, state.request, state.mq_conn)
        fail_pipeline(state, :permission_denied, "User #{state.request["sender"]["handle"]} denied access to '#{current}'")
    end
  end

  @doc """
  `run_command` -> {:next_state, :wait_for_command}

  Runs the command.
  """
  def run_command(:timeout, %__MODULE__{current_bound: current_bound,
                                        request: request}=state) do
    {bundle, name} = Models.Command.split_name(current_bound.command)
    case Cog.Relay.Relays.pick_one(bundle) do
      nil ->
        msg = "No Cog Relays supporting the `#{bundle}` bundle are currently online"
        Helpers.send_error(msg, state.request, state.mq_conn)
        fail_pipeline(state, :no_relays, msg)
      relay ->
        topic = "/bot/commands/#{relay}/#{bundle}/#{name}"
        reply_to_topic = "#{state.topic}/reply"
        req = request_for_invocation(current_bound, request["sender"], request["room"], reply_to_topic)

        log_dispatch(state, relay)

        Connection.publish(state.mq_conn, Spanner.Command.Request.encode!(req), routed_by: topic)
        {:next_state, :wait_for_command, state, @command_timeout}
    end
  end

  @doc """
  `wait_for_command` -> {:stop, :shutdown} | {:next_state, :bind}

  Waits for the command to return. If there is an error or it is the last command
  in the pipeline, the executor shuts down. If it isn't the last command the next
  command is sent to parse.

  note: Check `handle_info({:publish, topic, message}, :wait_for_command, state)`
  """
  def wait_for_command(:timeout, state) do
    Helpers.send_timeout(state.current.command, state.request, state.mq_conn)
    fail_pipeline(state, :timeout, "Timed out waiting on #{state.current.command} to reply")
  end

  def handle_info({:publish, topic, message}, :wait_for_command, state) do
    reply_topic = "#{state.topic}/reply"
    case topic do
      ^reply_topic ->
        case Carrier.CredentialManager.verify_signed_message(message) do
          {true, payload} ->
            resp = Spanner.Command.Response.decode!(payload)
            case resp.status do
              "error" ->
                Helpers.send_error(resp.status_message, state.request, state.mq_conn)
                fail_pipeline(state, :command_error, resp.status_message)
              "ok" ->
                prepare_or_finish(state, resp)
            end
          false ->
            fail_pipeline(state, :message_authenticity, "Message signature not verified! #{inspect message}")
        end
      _ ->
        {:next_state, :wait_for_command, state}
    end
  end
  def handle_info(_, state_name, state) do
    {:next_state, state_name, state}
  end

  def handle_event(_event, state_name, state) do
    {:next_state, state_name, state}
  end

  def handle_sync_event(_event, _from, state_name, state) do
    {:reply, :ignored, state_name, state}
  end

  def code_change(_old_vsn, state_name, state, _extra) do
    {:ok, state_name, state}
  end

  def terminate(_reason, _state_name, %__MODULE__{error_type: nil}=state),
    do: log_success(state)
  def terminate(_reason, _state_name, state),
    do: log_failure(state)

  ########################################################################
  # Private functions

  defp lookup_room("me", state) do
    user_id = state.request["sender"]["id"]
    adapter = get_adapter_api(state.request["adapter"])
    adapter.lookup_direct_room(user_id: user_id, as_user: user_id)
  end
  defp lookup_room("here", state) do
    {:ok, state.request["room"]}
  end
  defp lookup_room(redir, state) do
    adapter = get_adapter_api(state.request["adapter"])
    adapter.lookup_room(redir, as_user: state.request["sender"]["id"])
  end

  # Render a templated response and send it out to all pipeline
  # destinations. Renders template only once.
  defp send_user_resp(%Spanner.Command.Response{}=resp, %__MODULE__{redirects: redirects}=state) do
    response_fn = response_fn(resp, state.request["adapter"])
    case redirects do
      [] ->
        publish_response(response_fn, state.request["room"], state)
      _ ->
        Enum.each(redirects, fn(destination) ->
          publish_response(response_fn, destination, state)
        end)
    end
  end

  # Create a function that accepts a room and generates an appropriate
  # response map. The template is rendered for the response once and
  # the result is embedded in the returned function.
  #
  # This enables us to render a template only once, regardless of how
  # many destinations we ultimately forward the response to.
  defp response_fn(%Spanner.Command.Response{body: body, template: template, bundle: bundle}, adapter) do
    bundle_id = case bundle do
                  nil -> nil
                  _ -> Cog.Queries.Bundles.bundle_id_from_name(bundle) |> Cog.Repo.one!
                end
    text = render_template(bundle_id, adapter, template, body)
    fn(room) ->
      %{response: text,
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

  # Could be a raw response or rendered lines of output; render each line separately
  defp render_template(bundle_id, adapter, nil, context) when is_list(context) do
    Enum.map_join(context, "\n", &render_template(bundle_id, adapter, nil, &1))
  end
  # Rendered lines of output; render each line of text separately
  defp render_template(bundle_id, adapter, nil, %{"body" => context}) when is_list(context) do
    Enum.map_join(context, "\n", &render_template(bundle_id, adapter, "text", &1))
  end
  # Missing template; find something that fits the context
  defp render_template(bundle_id, adapter, nil, context) do
    template = default_template(context)
    render_template(bundle_id, adapter, template, context)
  end
  # Render the provided template
  defp render_template(bundle_id, adapter, template, context) do
    fun = TemplateCache.lookup(bundle_id, adapter, template)
    fun.(context)
  end

  defp prepare_or_finish(%__MODULE__{input: [], output: [], remaining: []}=state, resp) do
    send_user_resp(resp, state)
    {:stop, :shutdown, %{state | output: resp.body}}
  end
  defp prepare_or_finish(%__MODULE__{input: [], output: output, remaining: []}=state, resp) do
    final_result = output ++ [resp.body]
    send_user_resp(%{resp | body: final_result}, state)
    {:stop, :shutdown, %{state | output: final_result}}
  end

  defp prepare_or_finish(%__MODULE__{input: [h|t], output: output}=state, resp) do
    scope = Bind.Scope.from_map(h)
    {:next_state, :bind, %{state | input: t, output: output ++ [resp.body], scope: scope}, 0}
  end
  defp prepare_or_finish(%__MODULE__{input: [], remaining: [h|t], output: output}=state, resp) do
    [oh|ot] = List.flatten(output ++ [resp.body])
    scope = Bind.Scope.from_map(oh)
    {:next_state, :bind, %{state | current: h, remaining: t, input: ot, output: [], scope: scope}, 0}
  end

  defp prepare(%__MODULE__{pipeline: %Ast.Pipeline{invocations: invocations}}=state) do
    [current|remaining] = invocations
    {:next_state, :bind, %{state | current: current, remaining: remaining}, 0}
  end

  defp request_for_invocation(invoke, requestor, room, reply_to) do
    %Spanner.Command.Request{command: invoke.command, options: invoke.options,
                             args: invoke.args, requestor: requestor,
                             room: room, reply_to: reply_to}
  end

  defp get_adapter_api(adapter) when is_binary(adapter),
    do: String.to_existing_atom("Elixir.Cog.Adapters.#{adapter}.API")

  defp sanitize_request(request) do
    prefix = Application.get_env(:cog, :command_prefix, "!")
    # Strip off command prefix before parsing
    text = Regex.replace(~r/^#{prefix}/, request["text"], "")
    # Replace '&amp;' with '&' (thanks Slack!)
    text = Regex.replace(~r/&amp;/, text, "&")
    # Replace unicode long dash with '--' to reverse OS X's replacement via the
    # "Smart Dashes" substitution, which is enabled by default
    text = Regex.replace(~r/—/, text, "--")
    # Decode Html Entities
    text = HtmlEntities.decode(text)
    # Update request with sanitized input
    Map.put(request, "text", text)
    end

  # Shorthand for ending a pipeline with the appropriate error message
  #
  # There isn't a corresponding `succeed_pipeline` because all it
  # would return is `{:stop, :shutdown, state}`
  defp fail_pipeline(state, error, message),
    do: {:stop, :shutdown, %{state | error_type: error, error_message: message}}

  defp log_initialization(%__MODULE__{id: id, request: request}) do
    PipelineEvent.initialized(id, request["text"], request["adapter"], request["sender"]["handle"])
    |> log_as_json
  end

  defp log_dispatch(%__MODULE__{id: id, current_bound: current_bound}=state, relay) do
    PipelineEvent.dispatched(id, elapsed(state), to_string(current_bound), relay)
    |> log_as_json
  end

  defp log_success(%__MODULE__{id: id, output: output}=state) do
    PipelineEvent.succeeded(id, elapsed(state), output)
    |> log_as_json
  end

  defp log_failure(%__MODULE__{id: id}=state) do
    PipelineEvent.failed(id, elapsed(state), state.error_type, state.error_message)
    |> log_as_json
  end

  defp log_as_json(event),
    do: Logger.info(Poison.encode!(event))

  # Return elapsed microseconds from when the pipeline started
  defp elapsed(%__MODULE__{started: started}),
    do: :timer.now_diff(:os.timestamp(), started)

end
