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
  * :check_primitive
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
  * `:current` - The current command invocation in the pipeline executor.
  * `:current_bound` - The current command invocation after binding to the scope.
  * `:remaining` - The remaining invocations in the pipeline.
  * `:input` - When commands return a list of results those results are added to
              an input buffer and the next command is executed once per item in
              the input buffer. Kind of an xargs style behavior by default.
  * `:output` - The accumulated output of commands executed with a list of results.

  """

  @type state :: %__MODULE__{
    id: String.t,
    topic: String.t,
    started: String.t,
    mq_conn: pid(),
    request: Spanner.Command.Request,
    scope: Piper.Bind.Scope,
    pipeline: Piper.Ast.Pipeline,
    redirects: List.t,
    current: Piper.Ast.Invocation,
    current_bound: Piper.Ast.Invocation,
    remaining: List.t,
    input: List.t,
    output: List.t
  }

  defstruct [id: nil, topic: nil, mq_conn: nil, request: nil,
             scope: nil, pipeline: nil, redirects: [], current: nil,
             current_bound: nil, remaining: [], input: [], output: [],
             started: nil]

  @behaviour :gen_fsm

  # Timeout for commands once they are in the `run_command` state
  @command_timeout 60000

  require Logger
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

  def start_link(request) do
    :gen_fsm.start_link(__MODULE__, [request], [])
  end

  @doc """
  `init` -> {:next_state, :wait_for_connect}

  Initializes the executor
  """
  def init([request]) when is_map(request) do
    request = sanitize_request(request)
    {:ok, conn} = Carrier.Messaging.Connection.connect()
    id = UUID.uuid4(:hex)
    topic = "/bot/pipelines/#{id}"

    Carrier.Messaging.Connection.subscribe(conn, topic <> "/+")

    Logger.info("Command pipeline #{id} initialized")
    {:ok, :parse, %__MODULE__{id: id, topic: topic, request: request,
                              mq_conn: conn,
                              scope: Bind.Scope.empty_scope(),
                              input: [], output: [],
                              started: :os.timestamp()}, 0}
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
        Logger.error("Error parsing command pipeline '#{state.request["text"]}': #{msg}")
        Helpers.send_reply(msg, state.request, state.mq_conn)
        {:stop, :shutdown, state}
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
        {:stop, :shutdown, state}
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
        Logger.error("Error preparing to execute command pipeline '#{state.request["text"]}': #{msg}")
        Helpers.send_reply(msg, state.request, state.mq_conn)
        {:stop, :shutdown, state}
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
        {:next_state, :check_primitive, %{state | current_bound: current_bound}, 0}
      :not_found ->
        Logger.error("#{state.id} Command '#{current_bound.command}' not found")
        Helpers.send_idk(state.request, current_bound.command, state.mq_conn)
        {:stop, :shutdown, state}
      {:error, msg} ->
        Logger.error("#{state.id} Error parsing options: #{msg}")
        Helpers.send_error(msg, state.request, state.mq_conn)
        {:stop, :shutdown, state}
    end
  end

  @doc """
  `check_primitive` -> {:next_state, :run_command} | {:next_state, :check_permission}

  If the command is primitive then the permission check is skipped and the command
  is executed.
  """
  def check_primitive(:timeout, %__MODULE__{current_bound: current_bound}=state) do
    {:ok, command} = CommandCache.fetch(current_bound)
    if command.primitive do
      {:next_state, :run_command, state, 0}
    else
      {:next_state, :check_permission, state, 0}
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
        Logger.debug("Ignoring message from unknown user #{state.request["sender"]["handle"]}")
        {:stop, :shutdown, state}
      :allowed ->
        {:next_state, :run_command, state, 0}
      {:no_rule, _invoke} ->
        Logger.info("No rule matching '#{current}'")
        why = "No rules match the supplied invocation of '#{current}'. Check your args and options, then confirm that the proper rules are in place."
        Helpers.send_denied(current, why, state.request, state.mq_conn)
        {:stop, :shutdown, state}
      {:denied, _invoke, rule} ->
        Logger.info("User #{state.request["sender"]["handle"]} denied access to '#{current}'")
        why = "You will need the '#{rule.permission_selector.perms.value}' permission to run this command."
        Helpers.send_denied(current, why, state.request, state.mq_conn)
        {:stop, :shutdown, state}
    end
  end

  @doc """
  `run_command` -> {:next_state, :wait_for_command}

  Runs the command.
  """
  def run_command(:timeout, %__MODULE__{current_bound: current_bound}=state) do
    case send_to_command(%{state | current_bound: current_bound}) do
      :stop ->
        {:stop, :shutdown, state}
      _ ->
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
    Logger.error("Command pipeline #{state.id} timed out waiting on #{state.current.command} to reply")
    Helpers.send_timeout(state.current.command, state.request, state.mq_conn)
    {:stop, :shutdown, state}
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
                {:stop, :shutdown, state}
              "ok" ->
                prepare_or_finish(state, resp)
            end
          false ->
            Logger.error("Message signature not verified! #{inspect message}")
            {:stop, :shutdown, state}
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

  def terminate(_reason, _state_name, state) do
    now = :os.timestamp()
    Logger.info("Command pipeline #{state.id} finished in #{:timer.now_diff(now, state.started)}\u00b5s")
  end

  # Private functions

  defp send_user_resp(%Spanner.Command.Response{}=resp, %__MODULE__{}=state) do
    send_user_resp(resp, state.redirects, state)
  end

  defp send_user_resp(%Spanner.Command.Response{}=resp, [redir|[]], state) do
    publish_response(resp, redir, state)
  end
  defp send_user_resp(%Spanner.Command.Response{}=resp, [redir|rest], state) do
    publish_response(resp, redir, state)
    send_user_resp(resp, rest, state)
  end
  defp send_user_resp(%Spanner.Command.Response{}=resp, [], state) do
    publish_response(resp, state.request["room"], state)
  end

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

  defp publish_response(%Spanner.Command.Response{body: body, template: template, bundle: bundle}, room, state) do
    adapter = state.request["adapter"]
    bundle_id = case bundle do
      nil -> nil
      _ -> Cog.Queries.Bundles.bundle_id_from_name(bundle) |> Cog.Repo.one!
    end
    text = render_template(bundle_id, adapter, template, body)
    response = %{response: text,
                 room: room,
                 adapter: adapter}
    Carrier.Messaging.Connection.publish(state.mq_conn, response, routed_by: state.request["reply"])
  end

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
    {:stop, :shutdown, state}
  end
  defp prepare_or_finish(%__MODULE__{input: [], output: output, remaining: []}=state, resp) do
    send_user_resp(%{resp | body: output ++ [resp.body]}, state)
    {:stop, :shutdown, state}
  end
  defp prepare_or_finish(%__MODULE__{input: [h|t], output: output}=state, resp) do
    case resp.status do
      "ok" ->
        scope = Bind.Scope.from_map(h)
        {:next_state, :bind, %{state | input: t, output: output ++ [resp.body], scope: scope}, 0}
      "error" ->
        Helpers.send_error(resp.status_message, state.request, state.mq_conn)
        {:stop, :shutdown, state}
    end
  end
  defp prepare_or_finish(%__MODULE__{input: [], remaining: [h|t], output: output}=state, resp) do
    case resp.status do
      "ok" ->
        [oh|ot] = List.flatten(output ++ [resp.body])
        scope = Bind.Scope.from_map(oh)
        {:next_state, :bind, %{state | current: h, remaining: t, input: ot, output: [], scope: scope}, 0}
      "error" ->
        Helpers.send_error(resp.status_message, state.request, state.mq_conn)
        {:stop, :shutdown, state}
    end
  end

  defp prepare(%__MODULE__{pipeline: %Ast.Pipeline{invocations: invocations}}=state) do
    [current|remaining] = invocations
    {:next_state, :bind, %{state | current: current, remaining: remaining}, 0}
  end

  defp send_to_command(%__MODULE__{current_bound: current_bound, request: request}=state) do
    {bundle, name} = Models.Command.split_name(current_bound.command)
    case Cog.Relay.Relays.pick_one(bundle) do
      nil ->
        Helpers.send_error("No Cog Relays supporting the `#{bundle}` bundle are currently online", request, state.mq_conn)
        :stop
      relay ->
        topic = "/bot/commands/#{relay}/#{bundle}/#{name}"
        reply_to_topic = "#{state.topic}/reply"
        req = request_for_invocation(current_bound, request["sender"], request["room"], reply_to_topic)
        Logger.debug("Dispatched invocation for command #{current_bound.command} on topic #{topic}")
        Carrier.Messaging.Connection.publish(state.mq_conn, Spanner.Command.Request.encode!(req), routed_by: topic)
    end
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
end
