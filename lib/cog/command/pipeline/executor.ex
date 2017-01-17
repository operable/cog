defmodule Cog.Command.Pipeline.Executor do

  alias Carrier.Messaging.ConnectionSup
  alias Carrier.Messaging.Connection
  alias Cog.Command.AuditMessage
  alias Cog.Chat.Adapter, as: ChatAdapter
  alias Cog.Command.CommandResolver
  alias Cog.Command.PermissionsCache
  alias Cog.Pipeline.Destination
  alias Cog.Command.Pipeline.Plan
  alias Cog.Command.Output
  alias Cog.Events.PipelineEvent
  alias Cog.Queries
  alias Cog.Relay.Relays
  alias Cog.Repo
  alias Cog.ServiceEndpoint
  alias Cog.Template
  alias Cog.Template.Evaluator
  alias Piper.Command.Ast
  alias Piper.Command.Parser
  alias Piper.Command.ParserOptions

  @command_statuses [:success, :abort, :error]

  @type provider_name :: String.t

  @typedoc """
  Custom State for executor

  ## Fields

  * `:id` - Generated id for the pipeline executor.
  * `:topic` - The topic that the executor listens on.
  * `:started` - Timestamp for the start of the pipeline.
  * `:mq_conn` - The message queue connection.
  * `:request` - The original request from the provider.
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
    started: DateTime.t,
    mq_conn: Carrier.Messaging.Connection.connection(),
    request: %Cog.Messages.ProviderRequest{}, # TODO: needs to be a type
    destinations: %{Atom.t => [Destination.t]},
    relays: Map.t,
    invocations: [%Piper.Command.Ast.Invocation{}], # TODO: needs to be a type
    current_plan: Cog.Command.Pipeline.Plan.t,
    plans: [Cog.Command.Pipeline.Plan.t],
    output: [Map.t],
    template: String.t, # Only used for bundles v4 and higher
    user: %Cog.Models.User{},
    user_permissions: [String.t],
    service_token: String.t,
    error_type: atom(),
    error_message: String.t,
    command_timeout: Int.t # Timeout for commands once they are in the `run_command` state
  }
  defstruct [
    id: nil,
    topic: nil,
    mq_conn: nil,
    request: nil,
    destinations: %{},
    relays: %{},
    invocations: [],
    current_plan: nil,
    plans: [],
    template: nil,
    output: [],
    started: nil,
    user: nil,
    user_permissions: [],
    service_token: nil,
    error_type: nil,
    error_message: nil,
    command_timeout: nil
  ]

  @behaviour :gen_fsm

  require Logger

  def start_link(request) do
    :gen_fsm.start_link(__MODULE__, [request], [])
  end

  def init([%Cog.Messages.ProviderRequest{}=request]) do
    config = Application.fetch_env!(:cog, Cog.Command.Pipeline)
    request = sanitize_request(request)
    {:ok, conn} = ConnectionSup.connect()
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
            command_timeout = get_command_timeout(request.provider, config)
            loop_data = %__MODULE__{id: id, topic: topic, request: request,
                                    mq_conn: conn,
                                    user: user,
                                    service_token: service_token,
                                    user_permissions: perms,
                                    output: initial_context,
                                    started: DateTime.utc_now(),
                                    command_timeout: command_timeout}
            initialization_event(loop_data)
            {:ok, :parse, loop_data, 0}
          {:error, :not_found} ->
            # Note: trigger-initiated pipelines will never get here,
            # as the user is checked in the HTTP controller

            # fake out enough state to use our common response infrastructure
            state = %__MODULE__{template: {:common, "unregistered-user"},
                                output: unregistered_user_data(request),
                                destinations: here_destination(request),
                                mq_conn: conn}
            respond(state, :error, "User not found")
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
                                 state.request.provider) do
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
    context = previous_output
    state = %{state | template: nil}

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
      {:error, reason} ->
        fail_pipeline_with_error({reason, bundle_name}, state)
      {:ok, {relay, relays}} ->
        topic = "/bot/commands/#{relay}/#{bundle_name}/#{command_name}"
        reply_to_topic = "#{state.topic}/reply"
        req = request_for_plan(current_plan, request, user, reply_to_topic, state.service_token)
        updated_state =  %{state | current_plan: current_plan, plans: remaining_plans, relays: relays}

        dispatch_event(updated_state, relay)
        Connection.publish(updated_state.mq_conn, req, routed_by: topic)

        {:next_state, :wait_for_command, updated_state, state.command_timeout}
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

        # If the status was "ok" or "abort", we still need to process
        # the output and update the state in the same way, so we'll
        # just encapsulate that logic here.
        update_state = fn(resp, state) ->
          # If there wasn't any response body, there's nothing to collect.
          # If there is, it can be a map or a list of maps; if the latter, we
          # want to accumulate it into one flat list
          collected_output = case resp.body do
                               nil ->
                                 state.output
                               body ->
                                 state.output ++ List.wrap(body)
                             end

          %{state | output: collected_output,
                    template: resp.template}
        end

        case resp.status do
          "ok" ->
            {:next_state, :execute_plan, update_state.(resp, state), 0}
          "abort" ->
            abort_pipeline(update_state.(resp, state))
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
  # Response Rendering Functions

  # TODO: remove bundle and room from command resp so commands can't excape their bundle.

  # Given pipeline output, apply templating as appropriate for each
  # provider/destination it is to be sent to, and send it to each.

  # Anything besides success should have a message
  defp respond(state, status) when status == :success,
    do: respond(state, status, nil)
  defp respond(state, status, message) when status in @command_statuses do
    state.destinations
    |> Map.keys
    |> Enum.each(&process_response(&1, state, status, message))
  end

  defp process_response(type, state, status, message) do
    output = output_for(type, state, status, message)
    state.destinations
    |> Map.get(type)
    |> Enum.each(&ChatAdapter.send(state.mq_conn, &1.provider, &1.room, output))
  end

  defp output_for(:chat, state, _, _) do
    output   = state.output
    template = state.template

    case template do
      {:common, template_name} when template_name in ["error", "unregistered-user"] ->
        # No "envelope" for these templates right now
        Evaluator.evaluate(template_name, output)
      {:common, template_name} ->
        Evaluator.evaluate(template_name,
                           Template.with_envelope(output))
      template_name ->
        parser_meta = state.current_plan.parser_meta
        Evaluator.evaluate(parser_meta.bundle_version_id,
                           template_name,
                           Template.with_envelope(output))
    end
  end
  defp output_for(:trigger, state, status, message) do
    envelope = %{status: status,
                 pipeline_output: state.output}
    if message do
      Map.put(envelope, :message, message)
    else
      envelope
    end
  end
  defp output_for(:status_only, _state, status, message) do
    envelope = %{status: status}
    if message do
      Map.put(envelope, :message, message)
    else
      envelope
    end
  end

  ########################################################################

  defp succeed_with_response(state) do
    respond(state, :success)
    {:stop, :shutdown, state}
  end

  defp succeed_early_with_response(state) do
    # If our pipeline has "run dry" at any point, we'll send a
    # response back to where the pipeline was initiated from.
    #
    # We don't want to send output to other destinations, because
    # you'd end up with "mystery" messages saying "Pipeline succeeded
    # but there was no output!" without indication of what's going
    # on.
    #
    # TODO: If the "early-exit" template gets more contextual smarts, we
    # could start returning to all destinations
    respond(%{state | template: {:common, "early-exit"},
                      destinations: here_destination(state.request)},
            :success, "Terminated early")
    {:stop, :shutdown, state}
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
                                        started: started, user: user}) do
    PipelineEvent.initialized(id, started, request.text, request.provider,
                              user.username, request.sender.handle)
    |> Probe.notify
  end

  defp dispatch_event(%__MODULE__{id: id, current_plan: plan}=state, relay) do
    PipelineEvent.dispatched(id, state.started,
                             plan.invocation_text,
                             relay, plan.cog_env)
    |> Probe.notify
  end

  defp success_event(%__MODULE__{id: id, output: output, started: started}) do
    PipelineEvent.succeeded(id, started, output)
    |> Probe.notify
  end

  defp failure_event(state) do
    PipelineEvent.failed(state.id, state.started, state.error_type, state.error_message)
    |> Probe.notify
  end

  ########################################################################
  # Unregistered User Functions

  defp unregistered_user_data(request) do
    handle   = request.sender.handle
    creators = user_creator_handles(request)

    {:ok, mention_name} = Cog.Chat.Adapter.mention_name(request.provider, handle)
    {:ok, display_name} = Cog.Chat.Adapter.display_name(request.provider)

    %{"handle" => handle,
      "mention_name" => mention_name,
      "display_name" => display_name,
      "user_creators" => creators}
  end

  # Returns a list of provider-appropriate "mention names" of all Cog
  # users with registered handles for the provider that currently have
  # the permissions required to create and manipulate new Cog user
  # accounts.
  #
  # The intention is to create a list of people that can assist
  # immediately in-chat when unregistered users attempt to interact
  # with Cog. Not every Cog user with these permissions will
  # necessarily have a chat handle registered for the chat provider
  # being used (most notably, the bootstrap admin user).
  defp user_creator_handles(request) do
    provider = request.provider

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
  # In general, chat-provider initiated pipelines will not be supplied
  # with an initial context.
  defp create_initial_context(%Cog.Messages.ProviderRequest{}=request) do
    context = List.wrap(request.initial_context)

    if Enum.all?(context, &is_map/1) do
      {:ok, context}
    else
      :error
    end
  end

  defp user_error(error, state) do
    id = state.id
    initiator = sender_name(state)
    pipeline_text = state.request.text
    error_message = Output.format_error(error)

    planning_failure = case state do
      %{invocations: [%Ast.Invocation{} = planning_failure|_]} ->
        to_string(planning_failure)
      _ ->
        ""
    end

    execution_failure = case state do
      %{current_plan: %Plan{invocation_text: execution_failure}} ->
        to_string(execution_failure)
      _ ->
        ""
    end

    %{"id" => id,
      "started" => Calendar.ISO.to_string(state.started),
      "initiator" => initiator,
      "pipeline_text" => pipeline_text,
      "error_message" => error_message,
      "planning_failure" => planning_failure,
      "execution_failure" => execution_failure}
  end

  defp abort_pipeline(%__MODULE__{current_plan: plan}=state) do
    message = AuditMessage.render({:abort_pipeline, plan.parser_meta.full_command_name},
                                  state.request)

    respond(state, :abort, message)
    fail_pipeline(state, :aborted, message)
  end

  # Catch-all function that sends an error message back to the user,
  # emits a pipeline failure audit event, and terminates the pipeline.
  defp fail_pipeline_with_error({reason, _detail}=error, state) do
    state = %{state | destinations: here_destination(state.request),
              template: {:common, "error"},
              output: user_error(error, state)}

    audit_message = AuditMessage.render(error, state.request)
    respond(state, :error, audit_message)
    fail_pipeline(state, reason, audit_message)
  end

  defp sender_name(state) do
    if ChatAdapter.is_chat_provider?(state.request.provider) do
      "@#{state.request.sender.handle}"
    else
      state.request.sender.id
    end
  end

  defp here_destination(request) do
    {:ok, destinations} = Destination.process(["here"],
                                              request.sender,
                                              request.room,
                                              request.provider)
    destinations
  end

  ########################################################################
  # Miscellaneous Functions

  defp request_for_plan(plan, request, user, reply_to, service_token) do
    # TODO: stuffing the provider into requestor here is a bit
    # code-smelly; investigate and fix
    provider  = request.provider
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
      services_root:   ServiceEndpoint.url()
    }
  end

  defp sanitize_request(%Cog.Messages.ProviderRequest{text: text}=request) do
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
          # Store the selected relay in the relay cache
          {:ok, relay} ->
            {:ok, {relay, Map.put(relays, bundle_name, relay)}}
          error ->
            # Query DB to clarify error before reporting to the user
            if Cog.Repository.Bundles.assigned_to_group?(bundle_name) do
              error
            else
              {:error, :no_relay_group}
            end
        end
      # Relay was previously assigned
      relay ->
        # Is the bundle still available on the relay? If not, remove the current assignment from the cache
        # and select a new relay
        if Relays.relay_available?(relay, bundle_name, bundle_version) do
          {:ok, {relay, relays}}
        else
          relays = Map.delete(relays, bundle_name)
          assign_relay(relays, bundle_name, bundle_version)
        end
    end
  end

  defp fetch_user_from_request(%Cog.Messages.ProviderRequest{}=request) do
    # TODO: This should happen when we validate the request
    if ChatAdapter.is_chat_provider?(request.provider) do
      provider   = request.provider
      sender_id = request.sender.id
      user = Queries.User.for_chat_provider_user_id(sender_id, provider)
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

  defp get_command_timeout(provider, config) do
    if ChatAdapter.is_chat_provider?(provider) do
      Keyword.fetch!(config, :interactive_timeout)
    else
      Keyword.fetch!(config, :trigger_timeout)
    end
    |> Cog.Config.convert(:ms)
  end
end
