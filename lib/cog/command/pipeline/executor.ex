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
  * :maybe_collect_command
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
  * `:context` - The execution context of the command.
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
    request: Spanner.Command.Request,
    scope: Piper.Bind.Scope,
    context: List.t | Map.t,
    pipeline: Piper.Ast.Pipeline,
    redirects: List.t,
    current: Piper.Ast.Invocation,
    current_bound: Piper.Ast.Invocation,
    remaining: List.t,
    input: List.t,
    output: List.t,
    user: %Cog.Models.User{},
    user_permissions: [String.t],
    error_type: atom(),
    error_message: String.t
  }

  defstruct [id: nil, topic: nil, mq_conn: nil, request: nil,
             scope: nil, context: nil, pipeline: nil, redirects: [],
             current: nil, current_bound: nil, remaining: [], input: [],
             output: [], started: nil, user: nil, user_permissions: [],
             error_type: nil, error_message: nil]

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
  use Cog.Util.Debug

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

    adapter = request["adapter"]
    handle = request["sender"]["handle"]
    # We resolve users and permissions at this stage so that we can
    # include the Cog user (and not just their adapter-specific
    # handle) in event logs (and also to prevent us doing unnecessary
    # work for users that don't have Cog accounts)
    case resolve_user_and_permissions(adapter, handle) do
      {:ok, {user, perms}} ->
        loop_data = %__MODULE__{id: id, topic: topic, request: request,
                                mq_conn: conn,
                                user: user,
                                user_permissions: perms,
                                input: [], output: [],
                                started: :os.timestamp()}
        initialization_event(loop_data)
        {:ok, :parse, loop_data, 0}
      {:error, :not_found} ->
        alert_unregistered_user(%__MODULE__{mq_conn: conn, request: request})
        :ignore
    end
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

    case resolve_redirects(redirs, state) do
      {:ok, resolved} ->
        prepare(%{state | redirects: resolved})
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

  @doc """
  `bind` -> {:next_state, :get_options}

  Binds the current invocation to the scope. The scope is created based on the
  context. nil context: blank scope, map context: singular scope, list context:
  multiple scopes
  """
  def bind(:timeout, %__MODULE__{current: current, context: context}=state) do
    scope = get_scope(context)
    |> resolve_scope(current)
    case bind_scope(scope, current) do
      {:error, {:not_found, var}} ->
        Helpers.send_reply("I can't find the variable '$#{var}'.", state.request, state.mq_conn)
        fail_pipeline(state, :binding_error, "Error preparing to execute command pipeline '#{state.request["text"]}': Unknown variable '#{var}'")
      {:error, msg} ->
        Helpers.send_reply(msg, state.request, state.mq_conn)
        fail_pipeline(state, :binding_error, "Error preparing to execute command pipeline '#{state.request["text"]}': #{msg}")
      bound ->
        {current_bound, bound_scope} = collect_bound(bound)
        {:next_state, :get_options, %{state | current_bound: current_bound, scope: bound_scope}, 0}
    end
  end

  @doc """
  `get_options` -> {:stop, :shutdown} | {:next_state, :check_permission}

  Runs the option interpreter on the current bound invocation.
  """
  def get_options(:timeout, %__MODULE__{current_bound: current_bound}=state) do
    case interpret_options(current_bound) do
      {:ok, current_bound} ->
        {:next_state, :maybe_enforce, %{state | current_bound: current_bound}, 0}
      {:not_found, current_bound} ->
        Helpers.send_idk(state.request, current_bound.command, state.mq_conn)
        fail_pipeline(state, :option_interpreter_error, "Command '#{current_bound.command}' not found")
      error ->
        {:error, msg} = error
        Helpers.send_error(msg, state.request, state.mq_conn)
        fail_pipeline(state, :option_interpreter_error, "Error parsing options: #{inspect error}")
    end
  end

  @doc """
  `maybe_enforce` -> {:next_state, :maybe_collect_command} | {:next_state, :check_permission}

  If the command is enforced then the permission check is skipped and the command
  is executed.
  """
  def maybe_enforce(:timeout, %__MODULE__{current_bound: current_bound}=state) do
    if enforce?(current_bound) do
      {:next_state, :check_permission, state, 0}
    else
      {:next_state, :maybe_collect_command, state, 0}
    end
  end

  @doc """
  `check_permission` -> {:stop, :shutdown} | {:next_state, :maybe_collect_command}

  Checks to see if the user has permission to execute the current command. We
  run check permissions here because this is the first time we have all the
  information available to determine if the user has the proper perms.
  """
  def check_permission(:timeout, %__MODULE__{current: current, current_bound: current_bound}=state) do
    case interpret_permissions(current_bound, state.user, state.user_permissions) do
      :allowed ->
        {:next_state, :maybe_collect_command, state, 0}
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
  `maybe_collect_command` -> {:next_state, :run_command}

  If the command is of the `once` execution type current_bound will be a list
  of the same command with potentially different options and args. At this point
  we combine everything in preperation of execution.
  """
  def maybe_collect_command(:timeout, %__MODULE__{current_bound: current_bound}=state) when is_list(current_bound) do
    options = Enum.map(current_bound, &(&1.options))
    args = Enum.map(current_bound, &(&1.args))
    |> List.flatten
    [first_current_bound|_] = current_bound
    current_bound = %{first_current_bound | options: options, args: args}
    {:next_state, :run_command, %{state | current_bound: current_bound}, 0}
  end
  def maybe_collect_command(:timeout, state),
    do: {:next_state, :run_command, state, 0}

  @doc """
  `run_command` -> {:next_state, :wait_for_command}

  Runs the command.
  """
  def run_command(:timeout, %__MODULE__{current_bound: current_bound,
                                        request: request}=state) do
    {bundle, name} = Models.Command.split_name(current_bound.command)
    case Cog.Command.BundleCache.status(bundle) do
      {:ok, :enabled} ->
        case Cog.Relay.Relays.pick_one(bundle) do
          nil ->
            msg = "No Cog Relays supporting the `#{bundle}` bundle are currently online"
            Helpers.send_error(msg, state.request, state.mq_conn)
            fail_pipeline(state, :no_relays, msg)
          relay ->
            topic = "/bot/commands/#{relay}/#{bundle}/#{name}"
            reply_to_topic = "#{state.topic}/reply"
            cog_env = maybe_add_env(current_bound, state)
            req = request_for_invocation(current_bound, request["sender"], request["room"], request["adapter"], reply_to_topic, cog_env)

            dispatch_event(state, relay)

            Connection.publish(state.mq_conn, Spanner.Command.Request.encode!(req), routed_by: topic)
            {:next_state, :wait_for_command, state, @command_timeout}
        end
      {:ok, :disabled} ->
        msg = "The `#{bundle}` bundle is currently disabled"
        Helpers.send_error(msg, state.request, state.mq_conn)
        fail_pipeline(state, :no_relays, msg)
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
                Helpers.send_error(resp.status_message || resp.body["message"], state.request, state.mq_conn)
                fail_pipeline(state, :command_error, resp.status_message || resp.body["message"])
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
    do: success_event(state)
  def terminate(_reason, _state_name, state),
    do: failure_event(state)

  ########################################################################
  # Private functions

  # Convert all redirects to adapter-specific rooms. If any redirects
  # are invalid for any reason, returns an error with the list of
  # invalid redirects.
  defp resolve_redirects(redirects, state) do
    case redirects
    |> Enum.map(&lookup_room(&1, state))
    |> Enum.partition(&is_ok/1) do
      {found, []} ->
        {:ok, Enum.map(found, &unwrap_tuple/1)}
      {_, invalid} ->
        {:error, Enum.map(invalid, &unwrap_tuple/1)}
    end
  end

  # Returns {:ok, room} or {:error, invalid_redirect}
  defp lookup_room("me", state) do
    user_id = state.request["sender"]["id"]
    adapter = get_adapter_api(state.request["module"])
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
    adapter = get_adapter_api(state.request["module"])
    case adapter.lookup_room(redir) do
      {:ok, room} ->
        {:ok, room}
      {:error, reason} ->
        Logger.error("Error resolving redirect '#{redir}' with adapter #{adapter}: #{inspect reason}")
        {:error, {reason, redir}}
    end
  end

  defp is_ok({:ok, _}), do: true
  defp is_ok(_), do: false

  defp unwrap_tuple({:ok, value}), do: value
  defp unwrap_tuple({:error, value}), do: value

  # Render a templated response and send it out to all pipeline
  # destinations. Renders template only once.
  defp send_user_resp(%Spanner.Command.Response{}=resp, %__MODULE__{redirects: redirects}=state) do
    # TODO: remove bundle and room from command resp so commands can't excape their bundle.
    {bundle, _} = Models.Command.split_name(state.current_bound.command)

    response_fn = response_fn(%{resp | bundle: bundle}, state.request["adapter"])
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
    response_fn(text, adapter)
  end
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

  # Could be a raw response or rendered lines of output; render each line separately
  defp render_template(bundle_id, adapter, template, context) when is_list(context) do
    Enum.map_join(context, "\n", &render_template(bundle_id, adapter, template, &1))
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
    # If `TemplateCache.lookup/3` returns nil instead of a function,
    # we know that the adapter doesn't have a template with the given
    # name. In this case, we can fall back to no template and run
    # through render_template again to pick up a default
    #
    # This is *NOT* a long-term solution.
    case TemplateCache.lookup(bundle_id, adapter, template) do
      fun when is_function(fun) ->
        fun.(context)
      nil ->
        # Unfortunately, we don't have the bundle name or the command
        # name down here for this warning message :(
        Logger.warn("The template `#{template}` was not found for adapter `#{adapter}` in bundle `#{bundle_id}`; falling back to the default")
        render_template(bundle_id, adapter, nil, context)
    end
  end

  defp prepare_or_finish(%__MODULE__{input: [], output: [], remaining: []}=state, resp) do
    send_user_resp(resp, state)
    {:stop, :shutdown, %{state | output: resp.body}}
  end
  defp prepare_or_finish(%__MODULE__{input: [], output: output, remaining: []}=state, resp) do
    final_result = Enum.reject(output ++ [resp.body], &is_nil/1)
    send_user_resp(%{resp | body: final_result}, state)
    {:stop, :shutdown, %{state | output: final_result}}
  end
  defp prepare_or_finish(%__MODULE__{input: [h|t], output: output}=state, resp) do
    scope = Bind.Scope.from_map(h)
    {:next_state, :bind, %{state | input: t, output: output ++ [resp.body], scope: scope, context: h}, 0}
  end
  defp prepare_or_finish(%__MODULE__{input: [], output: output, remaining: [h|t]}=state, resp) do
    # Fetch the next command
    {:ok, command} = CommandCache.fetch(h)

    new_output = output ++ [resp.body]
    |> List.flatten
    |> Enum.reject(&is_nil/1)

    case new_output do
      [] ->
        error_message = "No output received from command '#{state.current}'"
        Helpers.send_error(error_message, state.request, state.mq_conn)
        fail_pipeline(state, :empty_output, error_message)
      _ ->
        case command.execution do
          "once" ->
            {:next_state, :bind, %{state | current: h, remaining: t, input: [], output: [], context: new_output}, 0}
          "multiple" ->
            [oh|ot] = new_output
            {:next_state, :bind, %{state | current: h, remaining: t, input: ot, output: [], context: oh}, 0}
        end
      end
  end

  defp prepare(%__MODULE__{pipeline: %Ast.Pipeline{invocations: invocations}}=state) do
    [current|remaining] = invocations
    {:next_state, :bind, %{state | current: current, remaining: remaining}, 0}
  end

  defp request_for_invocation(invoke, requestor, room, provider, reply_to, cog_env) do
    requestor = Map.put_new(requestor, "provider", provider)
    %Spanner.Command.Request{command: invoke.command, options: invoke.options,
                             args: invoke.args, requestor: requestor,
                             cog_env: cog_env, room: room, reply_to: reply_to}
  end

  defp maybe_add_env(invocation, state) do
    {:ok, command} = CommandCache.fetch(invocation)
    cond do
      !command.enforcing && command.calling_convention == "all" ->
        state.context
      true ->
        nil
    end
  end

  defp get_adapter_api(module),
    do: String.to_existing_atom("#{module}.API")

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

  defp initialization_event(%__MODULE__{id: id, request: request,
                                        user: user}) do
    PipelineEvent.initialized(id, request["text"], request["adapter"],
                              user.username, request["sender"]["handle"])
    |> Probe.notify
  end

  defp dispatch_event(%__MODULE__{id: id, current_bound: current_bound}=state, relay) do
    PipelineEvent.dispatched(id, elapsed(state), to_string(current_bound), relay)
    |> Probe.notify
  end

  defp success_event(%__MODULE__{id: id, output: output}=state) do
    PipelineEvent.succeeded(id, elapsed(state), output)
    |> Probe.notify
  end

  defp failure_event(%__MODULE__{id: id}=state) do
    PipelineEvent.failed(id, elapsed(state), state.error_type, state.error_message)
    |> Probe.notify
  end

  # Return elapsed microseconds from when the pipeline started
  defp elapsed(%__MODULE__{started: started}),
    do: :timer.now_diff(:os.timestamp(), started)

  # Helper functions for bind
  defp get_scope(context) when is_nil(context),
    do: Bind.Scope.empty_scope()
  defp get_scope(context) when is_list(context),
    do: Enum.map(context, &get_scope/1)
  defp get_scope(context),
    do: Bind.Scope.from_map(context)

  defp resolve_scope(scope, current) when is_list(scope),
    do: Enum.map(scope, &(resolve_scope(&1, current)))
  defp resolve_scope(scope, current),
    do: Bindable.resolve(current, scope)

  defp bind_scope(resolved_scope, current) when is_list(resolved_scope),
    do: bind_scope(resolved_scope, current, [])
  defp bind_scope({:ok, resolved_scope}, current),
    do: Bindable.bind(current, resolved_scope)
  defp bind_scope({:error, msg}, _),
    do: {:error, msg}

  defp bind_scope([resolved_scope|rest], current, acc) do
    case bind_scope(resolved_scope, current) do
      {:error, msg} ->
        {:error, msg}
      {:ok, current_bound, bound_scope} ->
        bind_scope(rest, current, [{:ok, current_bound, bound_scope}|acc])
    end
  end
  defp bind_scope([], _, acc),
    do: Enum.reverse(acc)

  defp collect_bound(binding) when is_list(binding),
    do: collect_bound(binding, {[], []})
  defp collect_bound({:ok, current_bound, bound_scope}),
    do: {current_bound, bound_scope}

  defp collect_bound([bound|rest], acc) do
    {:ok, current_bound, bound_scope} = bound
    {current_bound_list, bound_scope_list} = acc
    collect_bound(rest, {[current_bound|current_bound_list], [bound_scope|bound_scope_list]})
  end
  defp collect_bound([], acc) do
    {current_bound_list, bound_scope_list} = acc
    {Enum.reverse(current_bound_list), Enum.reverse(bound_scope_list)}
  end

  # Helper functions for get_options
  defp interpret_options(current_bound) when is_list(current_bound),
    do: interpret_options(current_bound, [])
  defp interpret_options(current_bound) do
    case OptionInterpreter.initialize(current_bound, current_bound.args) do
      {:ok, options, args} ->
        current_bound = %{current_bound | options: options, args: args}
        {:ok, current_bound}
      :not_found ->
        {:not_found, current_bound}
      error ->
        error
    end
  end

  defp interpret_options([current_bound|rest], acc) do
    case interpret_options(current_bound) do
      {:ok, current_bound} ->
        interpret_options(rest, [current_bound|acc])
      {:not_found, current_bound} ->
        {:not_found, current_bound}
      error ->
        error
    end
  end
  defp interpret_options([], acc),
    do: {:ok, acc}

  # Helper functions for may_enforce
  defp enforce?([current_bound|_]),
    do: enforce?(current_bound)
  defp enforce?(current_bound) do
    {:ok, command} = CommandCache.fetch(current_bound)
    command.enforcing
  end

  # Helper functions for check_permissions
  defp interpret_permissions([current_bound|rest], user, permissions) do
    case interpret_permissions(current_bound, user, permissions) do
      :ignore ->
        :ignore
      :allowed ->
        interpret_permissions(rest, user, permissions)
      {:no_rule, invoke} ->
        {:no_rule, invoke}
      {:denied, invoke, rule} ->
        {:denied, invoke, rule}
    end
  end
  defp interpret_permissions([], _, _),
    do: :allowed
  defp interpret_permissions(current_bound, user, permissions),
    do: PermissionInterpreter.check(current_bound, user, permissions)

  # We need to resolve the Cog user from their adapter-specific handle
  # for event logging purposes early on. We also grab their
  # permissions, since we'll need them later anyway
  defp resolve_user_and_permissions(adapter, handle),
    do: Cog.Command.UserPermissionsCache.fetch(username: handle, adapter: adapter)

  defp alert_unregistered_user(state) do
    response_fn = response_fn(unregistered_user_message(state.request),
                              state.request["adapter"])
    publish_response(response_fn, state.request["room"], state)
  end

  defp unregistered_user_message(request) do
    adapter = get_adapter_api(request["module"])
    mention_name = adapter.mention_name(request["sender"]["handle"])
    service_name = adapter.service_name
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
                         "You'll need to ask a Cog administrator to fix this situation and to register your #{service_name} handle."
                       _ ->
                         "You'll need to ask a Cog administrator to fix this situation and to register your #{service_name} handle; the following users can help you right here in chat: #{Enum.join(user_creators, ", ")} ."
                     end
    # Yes, that space between the last mention and the period is
    # significant, at least for Slack; it won't format the mention as
    # a mention otherwise, because periods are allowed in their handles.

    """
    #{mention_name}: I'm sorry, but either I don't have a Cog account for you, or your #{service_name} chat handle has not been registered. Currently, only registered users can interact with me.

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
    adapter_module = get_adapter_api(request["module"])

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

end
