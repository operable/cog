defmodule Cog.Command.Pipeline.Executor do

  alias Carrier.Messaging.Connection
  alias Cog.AuditMessage
  alias Cog.Chat.Adapter, as: ChatAdapter
  alias Cog.Command.CommandResolver
  alias Cog.Command.PermissionsCache
  alias Cog.Command.Pipeline.Destination
  alias Cog.Command.Pipeline.Plan
  alias Cog.Command.ReplyHelper
  alias Cog.ErrorResponse
  alias Cog.Events.PipelineEvent
  alias Cog.Queries
  alias Cog.Relay.Relays
  alias Cog.Repo
  alias Cog.ServiceEndpoint
  alias Cog.Template
  alias Piper.Command.Ast
  alias Piper.Command.Parser
  alias Piper.Command.ParserOptions

  # Last bundle configuration version that accepts the old
  # Mustache-based templates; later versions are processed
  # differently.
  @old_template_version 3

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
  * `:template` - The single template to render a response for bundles
    v4 and higher. This is defined as the last template received from
    a command response. Not used for v3 bundles and earlier.
  * `:template_version` - ONLY used until v3 bundles and earlier are
    phased out. This is the version of the bundle from which the
    template in `:template` comes from; we need to know in order to
    figure out how to do the final processing.
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
    request: %Cog.Messages.AdapterRequest{}, # TODO: needs to be a type
    destinations: [Destination.t],
    relays: Map.t,
    invocations: [%Piper.Command.Ast.Invocation{}], # TODO: needs to be a type
    current_plan: Cog.Command.Pipeline.Plan.t,
    plans: [Cog.Command.Pipeline.Plan.t],
    output: [{Map.t, String.t}], # {output, template}
    template: String.t, # Only used for bundles v4 and higher
    template_version: integer(), # ONLY used until v3 and earlier are phased out!
    user: %Cog.Models.User{},
    user_permissions: [String.t],
    service_token: String.t,
    error_type: atom(),
    error_message: String.t
  }
  defstruct [
    id: nil,
    topic: nil,
    mq_conn: nil,
    request: nil,
    destinations: [],
    relays: %{},
    invocations: [],
    current_plan: nil,
    plans: [],
    template: nil,
    template_version: nil,
    output: [],
    started: nil,
    user: nil,
    user_permissions: [],
    service_token: nil,
    error_type: nil,
    error_message: nil
  ]

  @behaviour :gen_fsm

  # Timeout for commands once they are in the `run_command` state
  @command_timeout 60000

  use Adz

  def start_link(request),
    do: :gen_fsm.start_link(__MODULE__, [request], [])

  def init([%Cog.Messages.AdapterRequest{}=request]) do
    request = sanitize_request(request)
    {:ok, conn} = Connection.connect()
    id = request.id
    topic = "/bot/pipelines/#{id}"
    Connection.subscribe(conn, topic <> "/+")

    service_token = Cog.Command.Service.Tokens.new

    # TODO: Fold initial context creation into decoding; we shouldn't
    # ever get anything invalid here
    case create_initial_context(request) do
      {:ok, initial_context} ->
        case fetch_user_from_request(request) do
          {:ok, user} ->
            {:ok, perms} = PermissionsCache.fetch(user)
            loop_data = %__MODULE__{id: id, topic: topic, request: request,
                                    mq_conn: conn,
                                    user: user,
                                    service_token: service_token,
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
    case Parser.scan_and_parse(state.request.text, options) do
      {:ok, %Ast.Pipeline{}=pipeline} ->
        case Destination.process(Ast.Pipeline.redirect_targets(pipeline),
                                 state.request.sender,
                                 state.request.room,
                                 state.request.adapter) do
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

  def plan_next_invocation(:timeout, %__MODULE__{output: []}=state),
    do: succeed_early_with_response(state)
  def plan_next_invocation(:timeout, %__MODULE__{invocations: [current_invocation|remaining],
                                                 output: previous_output,
                                                 user_permissions: permissions}=state) do
    state = %{state | current_plan: nil}
    # If a previous command generated output, we don't need to retain
    # any templating information, because the current command now
    # controls how the output will be presented
    context = strip_templates(previous_output)
    state = %{state | template: nil, template_version: nil}

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
      {:error, {:denied, rule}} ->
        fail_pipeline_with_error({:denied, {rule, current_invocation}}, state)
      {:error, msg} when is_binary(msg) ->
        # These are error strings that are generated from within the
        # binding infrastructure... should probably pull those strings
        # up to here instead
        fail_pipeline_with_error({:binding_error, msg}, state)
    end
  end
  def plan_next_invocation(:timeout, %__MODULE__{invocations: []}=state),
    do: succeed_with_response(state)

  def execute_plan(:timeout, %__MODULE__{plans: [current_plan|remaining_plans], relays: relays, request: request, user: user}=state) do
    bundle_name  = current_plan.parser_meta.bundle_name
    command_name = current_plan.parser_meta.command_name
    version      = current_plan.parser_meta.version

    # TODO: Previously, we'd do a test here for whether the bundle was
    # enabled or not. Now, we'll never make it this far if the bundle's not
    # enabled... which means we need to handle the disabled bundle
    # error higher up.
    #
    #   fail_pipeline_with_error({:disabled_bundle, bundle}, state)
    #
    case assign_relay(relays, bundle_name, version) do
      {nil, _} ->
        fail_pipeline_with_error({:no_relays, bundle_name}, state)
      {relay, relays} ->
        topic = "/bot/commands/#{relay}/#{bundle_name}/#{command_name}"
        reply_to_topic = "#{state.topic}/reply"
        req = request_for_plan(current_plan, request, user, reply_to_topic, state.service_token)
        updated_state =  %{state | current_plan: current_plan, plans: remaining_plans, relays: relays}

        dispatch_event(updated_state, relay)
        Connection.publish(updated_state.mq_conn, req, routed_by: topic)

        {:next_state, :wait_for_command, updated_state, @command_timeout}
    end

  end
  def execute_plan(:timeout, %__MODULE__{plans: []}=state),
    do: {:next_state, :plan_next_invocation, state, 0}

  def wait_for_command(:timeout, state),
    do: fail_pipeline_with_error({:timeout, state.current_plan.parser_meta.full_command_name}, state)

  def handle_info({:publish, topic, message}, :wait_for_command, state) do
    reply_topic = "#{state.topic}/reply" # TODO: bake this into state for easier pattern-matching?
    case topic do
      ^reply_topic ->
        resp = Cog.Messages.CommandResponse.decode!(message)
        case resp.status do
          "ok" ->
            collected_output = collect_output(resp, state.output)
            {:next_state, :execute_plan, %{state | output: collected_output,
                                           template: resp.template,
                                           template_version: state.current_plan.parser_meta.bundle_config_version},
             0}
          "abort" ->
            collected_output = collect_output(resp, state.output)
            abort_pipeline(%{state | output: collected_output})
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
  defp collect_output(resp, output) do
    case resp.body do
      nil ->
        # If there wasn't any output,
        # there's nothing to collect
        output
      body ->
        output ++ Enum.map(List.wrap(body),
                           &store_with_template(&1, resp.template))
        # body may be a map or a list
        # of maps; if the latter, we
        # want to accumulate it into
        # one flat list
    end
  end

  # Redirection Resolution Functions


  ########################################################################
  # Response Rendering Functions

  # TODO: remove bundle and room from command resp so commands can't excape their bundle.

  # Given pipeline output, apply templating as appropriate for each
  # adapter/destination it is to be sent to, and send it to each.
  defp respond(%__MODULE__{template_version: version}=state)
  when is_integer(version) and version <= @old_template_version do
    ########################################################################
    # THIS IS THE OLD TEMPLATE PROCESSING
    ########################################################################

    output = state.output
    parser_meta = state.current_plan.parser_meta
    by_output_level = Enum.group_by(state.destinations, &(&1.output_level))

    # Render full output first
    full = Map.get(by_output_level, :full, [])
    adapters = full |> Enum.map(&(&1.adapter)) |> Enum.uniq

    case Cog.Template.Old.Renderer.render_for_adapters(adapters, parser_meta, output) do
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

      # TODO: For the mesasge typing to work out, this has to be a
      # bare string... let's find a less hacky way to address things
      publish_response("ok", dest.room, dest.adapter, state)
    end)
  end
  defp respond(%__MODULE__{template_version: version}) when is_integer(version) do
    raise "Whoa, I don't know about template_version #{version} yet... somebody should fix that"
  end
  # This happens when the pipeline runs with no output... This is
  # totally a hack for now. This basically means we're going to be
  # falling back to a default template. Once we have the new template
  # rendering engine in place, though, we can just categorically use
  # new templates for defaults, so this won't really matter.
  #
  # To state it a different way: as long as this code is in place,
  # default templates are going to be old-style Mustache templates.
  defp respond(%__MODULE__{template_version: nil, template: nil}=state) do
    respond(%{state | template_version: @old_template_version})
  end
  defp respond(%__MODULE__{template_version: nil}=state) do
    # TODO: This shouldn't ever happen, and is only here to help debug
    # stuff as we add the new template rendering engine
    state = %{state | current_plan: "REDACTED FOR SIZE"}
    Logger.error(">>>>>>> state = #{inspect state, pretty: true}")
    raise "Whoa, nil template_version!"
  end

  defp succeed_with_response(state) do
    respond(state)
    # TODO: what happens if we fail due to a template error?
    {:stop, :shutdown, state}
  end

  defp succeed_early_with_response(state) do
    # If our pipeline has "run dry" at any point, we'll send a
    # response back to all destinations, but only if the pipeline was
    # initiated from chat.
    #
    # If it was initiated from a trigger, though, we don't want to
    # output to any chat destinations. Otherwise, you'd end up with
    # "mystery" messages saying "Pipeline succeeded but there was no
    # output!" without indication of what's going on. If we trigger
    # something that succeeds without output, we'll just be silent in
    # chat.

    filtered_destinations = if ChatAdapter.is_chat_provider?(state.request.adapter) do
      state.destinations
    else
      state.destinations
      |> Enum.reject(&(ChatAdapter.is_chat_provider?(&1.adapter)))
    end
    succeed_with_response(%{state |
                            destinations: filtered_destinations,
                            template: nil,
                            template_version: nil,
                            output: [{"Pipeline executed successfully, but no output was returned", nil}]})
  end

  defp publish_response(message, room, adapter, state),
    do: ChatAdapter.send(state.mq_conn, adapter, room, message)

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

    PipelineEvent.initialized(id, request.text, request.adapter,
                              user.username, request.sender.handle)
    |> Probe.notify
  end

  defp dispatch_event(%__MODULE__{id: id, current_plan: plan}=state, relay) do
    PipelineEvent.dispatched(id, elapsed(state),
                             plan.invocation_text,
                             relay, plan.cog_env)
    |> Probe.notify
  end

  defp success_event(%__MODULE__{id: id, output: output}=state) do
    elapsed_time = elapsed(state)
    elapsed_time_ms = round(elapsed_time / 1000)
    Logger.info("Pipeline #{id} ran for #{elapsed_time_ms} ms.")
    PipelineEvent.succeeded(id, elapsed_time, strip_templates(output))
    |> Probe.notify
  end

  defp failure_event(%__MODULE__{id: id}=state) do
    elapsed_time = elapsed(state)
    elapsed_time_ms = round(elapsed_time / 1000)
    Logger.info("Pipeline #{id} ran for #{elapsed_time_ms} ms.")
    PipelineEvent.failed(id, elapsed_time, state.error_type, state.error_message)
    |> Probe.notify
  end

  # Return elapsed microseconds from when the pipeline started
  defp elapsed(%__MODULE__{started: started}),
    do: :timer.now_diff(:os.timestamp(), started)

  ########################################################################
  # Unregistered User Functions

  defp alert_unregistered_user(state) do
    request = state.request
    handle = request.sender.handle
    creators = user_creator_handles(request)

    {:ok, mention_name} = Cog.Chat.Adapter.mention_name(state.request.adapter, handle)
    {:ok, display_name} = Cog.Chat.Adapter.display_name(state.request.adapter)

    context = %{
      handle: handle,
      mention_name: mention_name,
      display_name: display_name,
      user_creators: creators,
      user_creators?: Enum.any?(creators)
    }

    ReplyHelper.send_template(state.request, "unregistered_user", context, state.mq_conn)
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
    provider = request.adapter

    "operable:manage_users"
    |> Cog.Queries.Permission.from_full_name
    |> Cog.Repo.one!
    |> Cog.Queries.User.with_permission
    |> Cog.Queries.User.for_chat_provider(provider)
    |> Cog.Repo.all
    |> Enum.flat_map(&(&1.chat_handles))
    |> Enum.map(fn(h) ->
      {:ok, mention} = Cog.Chat.Adapter.mention_name(provider, h.handle)
      mention
    end)
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
  defp create_initial_context(%Cog.Messages.AdapterRequest{}=request) do
    context = List.wrap(request.initial_context)

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

  defp user_error(error, state) do
    id = state.id
    started = Cog.Events.Util.ts_iso8601_utc(state.started)
    initiator = sender_name(state)
    pipeline_text = state.request.text
    error_message = ErrorResponse.render(error)

    {planning_failure, execution_failure} = case state do
      %{current_plan: %Plan{invocation_text: planning_failure}} ->
        {to_string(planning_failure), false}
      %{invocations: [%Ast.Invocation{} = execution_failure|_]} ->
        {false, to_string(execution_failure)}
      _ ->
        {false, false}
    end

    context = %{
      id: id,
      started: started,
      initiator: initiator,
      pipeline_text: pipeline_text,
      error_message: error_message,
      planning_failure: planning_failure,
      execution_failure: execution_failure
    }

    Template.render("any", "error", context)
  end

  defp abort_pipeline(%__MODULE__{current_plan: plan}=state) do
    respond(state)
    audit_message = AuditMessage.render({:abort_pipeline, plan.parser_meta.full_command_name, state.id},
                                        state.request)
    fail_pipeline(state, :aborted, audit_message)
  end

  # Catch-all function that sends an error message back to the user,
  # emits a pipeline failure audit event, and terminates the pipeline.
  defp fail_pipeline_with_error({reason, _detail}=error, state) do
    {:ok, user_message} = user_error(error, state)
    publish_response(user_message,
                     state.request.room,
                     state.request.adapter,
                     state)

    audit_message = AuditMessage.render(error, state.request)
    fail_pipeline(state, reason, audit_message)
  end

  defp sender_name(state) do
    if ChatAdapter.is_chat_provider?(state.request.adapter) do
      "@#{state.request.sender.handle}"
    else
      state.request.sender.id
    end
  end

  ########################################################################
  # Miscellaneous Functions

  defp request_for_plan(plan, request, user, reply_to, service_token) do
    # TODO: stuffing the provider into requestor here is a bit
    # code-smelly; investigate and fix
    provider  = request.adapter
    requestor = request.sender |> Map.put_new("provider", provider)
    room      = request.room
    user      = Cog.Models.EctoJson.render(user)

    %Cog.Messages.Command{
      command:         plan.parser_meta.full_command_name,
      options:         plan.options,
      args:            plan.args,
      cog_env:         plan.cog_env,
      invocation_id:   plan.invocation_id,
      invocation_step: plan.invocation_step,
      requestor:       requestor,
      user:            user,
      room:            room,
      reply_to:        reply_to,
      service_token:   service_token,
      services_root:   ServiceEndpoint.public_url
    }
  end

  defp sanitize_request(%Cog.Messages.AdapterRequest{text: text}=request) do
    prefix = Application.get_env(:cog, :command_prefix, "!")

    text = text
    |> String.replace(~r/^#{Regex.escape(prefix)}/, "") # Remove command prefix
    |> String.replace(~r/“|”/, "\"")      # Replace OS X's smart quotes and dashes with ascii equivalent
    |> String.replace(~r/‘|’/, "'")
    |> String.replace(~r/—/, "--")
    |> HtmlEntities.decode                # Decode html entities

    # TODO: Fold this into decoding of the request initially?
    %{request | text: text}
  end

  defp assign_relay(relays, bundle_name, bundle_version) do
    case Map.get(relays, bundle_name) do
      # No assignment so let's pick one
      nil ->
        case Relays.pick_one(bundle_name, bundle_version) do
          # No relays available
          nil ->
            {nil, relays}
          # Store the selected relay in the relay cache
          relay ->
            {relay, Map.put(relays, bundle_name, relay)}
        end
      # Relay was previously assigned
      relay ->
        # Is the bundle still available on the relay? If not, remove the current assignment from the cache
        # and select a new relay
        if Relays.relay_available?(relay, bundle_name, bundle_version) do
          {relay, relays}
        else
          relays = Map.delete(relays, bundle_name)
          assign_relay(relays, bundle_name, bundle_version)
        end
    end
  end

  defp fetch_user_from_request(%Cog.Messages.AdapterRequest{}=request) do
    # TODO: This should happen when we validate the request
    if ChatAdapter.is_chat_provider?(request.adapter) do
      adapter   = request.adapter
      sender_id = request.sender.id

      user = Queries.User.for_chat_provider_user_id(sender_id, adapter)
      |> Repo.one

      case user do
        nil ->
          {:error, :not_found}
        user ->
          {:ok, user}
      end
    else
      cog_name = request.sender.id
      case Repo.get_by(Cog.Models.User, username: cog_name) do
        %Cog.Models.User{}=user ->
          {:ok, user}
        nil ->
          {:error, :not_found}
      end
    end
  end
end
