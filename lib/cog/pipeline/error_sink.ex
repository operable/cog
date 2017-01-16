defmodule Cog.Pipeline.ErrorSink do

  alias Experimental.GenStage
  alias Cog.Chat.Adapter, as: ChatAdapter
  alias Cog.Events.PipelineEvent
  alias Cog.Pipeline.DoneSignal
  alias Cog.Pipeline.Errors
  alias Cog.Pipeline
  alias Cog.Pipeline.Util
  alias Cog.Template.Evaluator


  @moduledoc ~s"""
  Specialized `GenStage` consumer to handle pipeline processing errors. When the
  module encounters an error wrapped in a `Cog.Pipeline.DoneSignal` it will produce output
  appropriate for the pipeline type (trigger or interactive) and route it
  to the proper destination.
  """

  use GenStage

  require Logger

  @type t :: %__MODULE__{
    all_events: [] | [DoneSignal.t],
    conn: Carrier.Messaging.Connection.t,
    owner: pid,
    policy: Cog.Pipeline.output_policy,
    request: Cog.Messages.ProviderRequest.t,
    pipeline: pid,
    started: DateTime.t
  }

  defstruct [:pipeline, :policy, :owner, :request, :started, :all_events, :conn]

  @doc ~s"""
  Starts a new `ErrorSink` process and connects it to the parent pipeline.

  ## Options
  * `:conn` - Pipeline's shared MQTT connection. Required.
  * `:owner` - Pid of the pipeline's owner process. Required.
  * `:policy` - Pipeline output policy. Required.
  * `:pipeline` - Pid of the parent pipeline. Required.
  * `:started` - Pipeline start timestamp. Required.
  * `:upstream` - Pid of the preceding pipeline stage. Required.
  """
  @spec start_link(opts :: Keyword.t) :: {:ok, pid} | {:error, any}
  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts)
  end

  def init(opts) do
    try do
      pipeline = Keyword.fetch!(opts, :pipeline)
      Process.monitor(pipeline)
      upstream = Keyword.fetch!(opts, :upstream)
      {:consumer, %__MODULE__{pipeline: pipeline,
                              owner: Keyword.fetch!(opts, :owner),
                              policy: Keyword.fetch!(opts, :policy),
                              request: Keyword.fetch!(opts, :request),
                              started: Keyword.fetch!(opts, :started),
                              conn: Keyword.fetch!(opts, :conn),
                              all_events: []},
       [subscribe_to: [upstream]]}
    rescue
      e in KeyError ->
        {:stop, {:error, Exception.message(e)}}
    end
  end

  def handle_events(events, _from, state) do
    events = Enum.filter(events, &keep_signal?/1)
    state = state
            |> Map.update(:all_events, events, &(&1 ++ events))
            |> process_errors
    {:noreply, [], state}
  end

  def handle_info({:DOWN, _mref, _, pipeline, _}, %__MODULE__{pipeline: pipeline}=state) do
    Logger.debug("Error sink for pipeline #{state.request.id} shutting down")
    {:stop, :normal, state}
  end
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  defp keep_signal?(%DoneSignal{}=signal), do: DoneSignal.error?(signal)
  defp keep_signal?(_), do: false

  defp process_errors(%__MODULE__{all_events: []}=state), do: state
  defp process_errors(state) do
    send_to_owner(state)
    state = if state.policy in [:adapter, :adapter_owner] do
      dests = Util.here_destination(state.request)
      Enum.each(state.all_events, &(send_to_adapter(&1, dests, state)))
      %{state | all_events: []}
    else
      state
    end
    Pipeline.notify(state.pipeline)
    state
  end

  defp send_to_adapter(%DoneSignal{}=signal, dests, state) do
    Enum.each(dests, &(send_to_adapter(&1, signal, state)))
  end
  defp send_to_adapter({type, targets}, signal, state) do
    context = prepare_error_context(signal, state)
    failure_event(signal.error, context["error_message"], state)
    output = output_for(type, signal, context)
    Enum.each(targets, &ChatAdapter.send(state.conn, &1.provider, &1.room, output))
  end

  defp send_to_owner(%__MODULE__{all_events: events, policy: policy, owner: owner}=state) when policy in [:owner, :adapter_owner] do
    Process.send(owner, {:pipeline, state.request.id, {:error, events}}, [])
  end
  defp send_to_owner(_), do: :ok

  defp prepare_error_context(signal, state) do
    error_message = Errors.lookup(signal)
    %{"id" => state.request.id,
      "initiator" => sender_name(state.request),
      "started" => state.started,
      "pipeline_text" => state.request.text,
      "error_message" => error_message,
      "planning_failure" => "",
      "execution_failure" => error_message}
  end

  defp output_for(:chat, signal, context) do
    Evaluator.evaluate(signal.template, context)
  end
  defp output_for(:trigger, _signal, context) do
    %{status: "error", pipeline_output: %{error_message: context["error_message"]}}
  end
  defp output_for(:status_only, _signal, context) do
    %{status: "error", pipeline_output: %{error_message: context["error_message"]}}
  end

  defp sender_name(request) do
    if ChatAdapter.is_chat_provider?(request.provider) do
      "@#{request.sender.handle}"
    else
      request.sender.id
    end
  end

  defp failure_event(error, error_message, state) do
    error_type = get_error_type(error)
    PipelineEvent.failed(state.request.id, state.started, error_type, error_message)
    |> Probe.notify
  end

  defp get_error_type({:error, type}), do: type
  defp get_error_type({:error, type, _}), do: type
end
