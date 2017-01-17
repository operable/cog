defmodule Cog.Pipeline.ExecutionStage do

  alias Experimental.GenStage
  alias Carrier.Messaging.Connection
  alias Cog.Config
  alias Cog.Events.PipelineEvent
  alias Cog.Pipeline.{Binder, OptionParser, PermissionEnforcer}
  alias Cog.Messages.{Command, CommandResponse}
  alias Cog.Pipeline.DataSignal
  alias Cog.Pipeline.DoneSignal
  alias Cog.Pipeline.RelaySelector
  alias Piper.Command.Ast.BadValueError

  @moduledoc ~s"""
  `GenStage` producer/consumer responsible for calling commands. Each
  `Piper.Command.Ast.Invocation` in a given pipeline is handled by a separate
  `ExecutionStage` process.

  ## Evaluating a command invocation

  This module's primary job is to evaluate a command invocation with a set of inputs.
  Inputs flow through the pipeline as `Cog.Pipeline.DataSignal` instances. Each instance
  contains a map of inputs which `ExecutionStage` uses as inputs to its command invocation.

  First, the inputs are bound to the invocation. Next, access rules are enforced based on the
  bound invocation and the requesting user. If the access rule check fails a `DoneSignal`
  containing the specific error is emitted and processing stops.

  If the check is successful then a `Cog.Messages.Command` instance is created and dispatched
  to a Relay hosting the targeted command. If the command responds with an error or if the dispatched
  command times out a `DoneSignal` containing the error is emitted and processing stops.

  ## Stream Position

  Cog's command API requires that commands are told when they are processing their first and last inputs
  for a given pipeline invocation. This information is kept in the `stream_position` field of the stage's
  state struct. When an `ExecutionStage` emits a `DoneSignal` containing an error `stream_position` is always
  set to `:end` and all future inputs will be ignored.
  """

  use GenStage

  require Logger
  require Command

  @type stream_position :: :init | :middle | :end

  @type t :: %__MODULE__{
    request_id: String.t,
    index: pos_integer,
    pipeline: pid,
    stream_position: stream_position,
    invocation: Piper.Command.Ast.Invocation.t,
    relay_selector: Cog.Pipeline.RelaySelector.t,
    sender: Cog.Chat.User.t,
    room: Cog.Chat.Room.t,
    user: Cog.Models.User.t,
    permissions: [] | [Cog.Models.Permission.t],
    service_token: String.t,
    topic: String.t,
    timeout: pos_integer,
    conn: Carrier.Messaging.Connection.t
  }

  defstruct [:request_id,
             :index,
             :pipeline,
             :stream_position,
             :invocation,
             :relay_selector,
             :sender,
             :room,
             :user,
             :permissions,
             :service_token,
             :topic,
             :timeout,
             :conn]

  @doc ~s"""
  Creates a new `ExecutionStage` process.

  ## Options
  * `:request_id` - Id assigned to originating request. Required.
  * `:index` - Zero-based pipeline position index. Required.
  * `:invocation` - `Piper.Command.Ast.Invocation` instance managed by the stage. Required.
  * `:conn` - Pipeline's shared MQTT connection. Required.
  * `:user` - User model for the submitting user. Required.
  * `:service_token` - Pipeline's service token. Required.
  * `:sender` - `Cog.Chat.User` for the submitting user. Required.
  * `:room` - `Cog.Chat.Room` for the originating request. Required.
  * `:timeout` - `Cog.Config.typed_interval`. Required.
  """
  @spec start_link(Keyword.t) :: {:ok, pid} | {:error, any}
  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts)
  end
  def init(opts) do
    try do
      pipeline = Keyword.fetch!(opts, :pipeline)
      # Monitor pipeline process so we know when to exit
      Process.monitor(pipeline)
      stage_opts = [subscribe_to: [Keyword.fetch!(opts, :upstream)], dispatcher: GenStage.BroadcastDispatcher]
      request_id = Keyword.fetch!(opts, :request_id)
      index = Keyword.fetch!(opts, :index)
      topic = "bot/pipelines/#{request_id}/#{index}"
      invocation = Keyword.fetch!(opts, :invocation)
      relay_selector = RelaySelector.new(invocation.meta.bundle_name, invocation.meta.version)
      conn = Keyword.fetch!(opts, :conn)
      case Connection.subscribe(conn, topic) do
        {:ok, _} ->
          {:producer_consumer, %__MODULE__{request_id: Keyword.fetch!(opts, :request_id),
                                           index: index,
                                           pipeline: pipeline,
                                           user: Keyword.fetch!(opts, :user),
                                           permissions: Keyword.fetch!(opts, :permissions),
                                           invocation: invocation,
                                           service_token: Keyword.fetch!(opts, :service_token),
                                           conn: conn,
                                           topic: topic,
                                           relay_selector: relay_selector,
                                           sender: Keyword.fetch!(opts, :sender),
                                           room: Keyword.fetch!(opts, :room),
                                           timeout: Keyword.fetch!(opts, :timeout) |> Config.convert(:ms),
                                           stream_position: :init}, stage_opts}
        error ->
          {:stop, error}
      end
    rescue
      e in KeyError ->
        {:stop, {:error, Exception.message(e)}}
    end
  end

  def handle_events(_events, _from, %__MODULE__{stream_position: :end}=state) do
    {:noreply, [], state}
  end
  def handle_events(in_events, _from, state) do
    [current|rest] = in_events
    {out_events, state} = process_events(current, rest, state, [])
    {:noreply, out_events, state}
  end

  def handle_info({:DOWN, _mref, _, pipeline, _}, %__MODULE__{pipeline: pipeline}=state) do
    {:stop, :normal, state}
  end
  def handle_info({:pipeline_complete, pipeline}, %__MODULE__{pipeline: pipeline}=state) do
    {:stop, :normal, state}
  end
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  def terminate(_reason, state) do
    Logger.debug("Execution stage #{state.index} for pipeline #{state.request_id} shutting down")
  end

  defp process_events(%DoneSignal{}=done, _, state, accum) do
    {accum ++ [done], state}
  end
  defp process_events(%DataSignal{}=current, [next|events], state, accum) do
    {current, state} = add_position(current, next, state)
    {out_events, state} = invoke_command(current, state)
    process_events(next, events, state, accum ++ Enum.reverse(out_events))
  end

  defp add_position(signal, %DoneSignal{}, %__MODULE__{stream_position: :init}=state) do
    signal = %{signal | position: "last"}
    {signal, %{state | stream_position: :end}}
  end
  defp add_position(signal, %DataSignal{}, %__MODULE__{stream_position: :init}=state) do
    signal = %{signal | position: "first"}
    {signal, %{state | stream_position: :middle}}
  end
  defp add_position(signal, %DoneSignal{}, %__MODULE__{stream_position: :middle}=state) do
    signal = %{signal | position: "last"}
    {signal, %{state | stream_position: :end}}
  end
  defp add_position(signal, _, %__MODULE__{stream_position: :middle}=state) do
    signal = %{signal | position: ""}
    {signal, state}
  end

  defp invoke_command(signal, %__MODULE__{timeout: timeout}=state) do
    started = DateTime.utc_now()
    topic = state.topic
    command_name = state.invocation.meta.command_name
    case RelaySelector.select(state.relay_selector) do
      {:ok, selector} ->
        state = %{state | relay_selector: selector}
        case signal_to_request(signal, state) do
          {:allowed, text, request} ->
            dispatch_event(text, request.cog_env, started, state)
            case Connection.publish(state.conn, request, routed_by: RelaySelector.relay_topic(state.relay_selector, command_name)) do
              :ok ->
                receive do
                  {:publish, ^topic, message} ->
                    process_response(CommandResponse.decode!(message), state)
                after timeout ->
                    {[%DoneSignal{error: {:error, :timeout}, invocation: text, template: "error"}], state}
                end
              error ->
                {[%DoneSignal{error: error}], state}
            end
          {:error, :denied, rule, text} ->
            {[%DoneSignal{error: {:error, :denied, rule}, invocation: text, template: "error"}], state}
          error ->
            {[%DoneSignal{error: error, invocation: "#{state.invocation}", template: "error"}], state}
        end
      error ->
        {[%DoneSignal{error: error}], state}
    end
  end

  defp signal_to_request(signal, state) do
    try do
      with {:ok, bound} <- Binder.bind(state.invocation, signal.data),
           {:ok, options, args} <- OptionParser.parse(bound),
             :allowed <- PermissionEnforcer.check(state.invocation.meta, options, args, state.permissions) do
        request = Command.create(state.invocation, options, args)
        {:allowed, "#{bound}", %{request | invocation_step: signal.position, requestor: state.sender,
                                 cog_env: signal.data, user: state.user, room: state.room, reply_to: state.topic,
                                 service_token: state.service_token, reply_to: state.topic}}
      else
        {:error, {:denied, rule}} -> {:error, :denied, rule, "#{state.invocation}"}
        {:error, {:missing_key, key}} -> {:error, :missing_key, key}
        {:error, _reason}=error -> error
      end
    rescue
      e in BadValueError ->
        {:error, BadValueError.message(e)}
    end
  end

  defp dispatch_event(text, cog_env, started, state) do
    event = PipelineEvent.dispatched(state.request_id, started, text,
                                     RelaySelector.relay(state.relay_selector), cog_env)
    Probe.notify(event)
  end

  defp process_response(response, state) do
    bundle_version_id = state.invocation.meta.bundle_version_id
    case response.status do
      "ok" ->
        if response.body == nil do
          {[], state}
        else
          if is_list(response.body) do
            {Enum.reduce_while(response.body, [],
                  &(expand_output(bundle_version_id, response.template, &1, &2))), state}
          else
            {[DataSignal.wrap(response.body, bundle_version_id, response.template)], state}
          end
        end
      "abort" ->
        signals = [DataSignal.wrap(response.body, bundle_version_id, response.template), %DoneSignal{}]
        {signals, state}
      "error" ->
        {[%DoneSignal{error: {:error, response.status_message || :unknown_error}}], state}
    end
  end

  defp expand_output(bundle_version_id, template, item, accum) when is_map(item) do
    {:cont, [DataSignal.wrap(item, bundle_version_id, template)|accum]}
  end
  defp expand_output(_bundle_version_id, _template, _item, _) do
    {:halt, [%DoneSignal{error: {:error, :badmap}}]}
  end

end
