defmodule Cog.Pipeline.OutputSink do

  alias Experimental.GenStage
  alias Cog.Chat.Adapter, as: ChatAdapter
  alias Cog.Events.PipelineEvent
  alias Cog.Pipeline
  alias Cog.Pipeline.{Destination, DataSignal, DoneSignal, Evaluator}
  alias Cog.Template
  alias Cog.Template.Evaluator

  @moduledoc ~s"""
  Specialized `GenStage` consumer to handle pipeline output. Accumulates
  `Cog.Pipeline.DataSignal`s until it receives a non-error `Cog.Pipeline.DoneSignal`.
  Then it generates appropriate output (executes Greenbar templates, etc) and routes it
  to the correct destinations.

  If a `DoneSignal` is received and no `DataSignal`s have been accumulated then
  `OutputSink` will use the early exit template to generate a response.
  """

  use GenStage

  require Logger

  @early_exit_template "early-exit"

  @type t :: %__MODULE__{
    all_events: [] | [DoneSignal.t],
    conn: Carrier.Messaging.Connection.t,
    destinations: Cog.Pipeline.Destination.destination_map,
    owner: pid,
    policy: Cog.Pipeline.output_policy,
    request: Cog.Messages.ProviderRequest.t,
    pipeline: pid,
    started: DateTime.t
  }
  defstruct [:request, :pipeline, :owner, :policy, :destinations, :all_events, :conn, :started]

  @doc ~s"""
  Starts a new `OutputSink` process and attaches it to the parent pipeline.

  ## Options
  * `:conn` - Pipeline's shared MQTT connection. Required.
  * `:destinations` - Map of output destinations grouped by type. Required.
  * `:policy` - Pipeline output policy. Required.
  * `:owner` - Pid of the pipeline's owner process. Required.
  * `:pipeline` - Pid of the parent pipeline. Required.
  * `:started` - Pipeline start timestamp. Required.
  * `:upstream` - Pid of the preceding pipeline stage. Required.
  """
  @spec start_link(Keyword.t) :: {:ok, pid} | {:error, any}
  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts)
  end

  def init(opts) do
    try do
      pipeline = Keyword.fetch!(opts, :pipeline)
      Process.monitor(pipeline)
      upstream = Keyword.fetch!(opts, :upstream)
      {:consumer, %__MODULE__{pipeline: pipeline,
                              request: Keyword.fetch!(opts, :request),
                              owner: Keyword.fetch!(opts, :owner),
                              destinations: Keyword.get(opts, :destinations, []),
                              all_events: [],
                              conn: Keyword.fetch!(opts, :conn),
                              started: Keyword.fetch!(opts, :started),
                              policy: Keyword.fetch!(opts, :policy)}, [subscribe_to: [upstream]]}
    rescue
      e in KeyError ->
        {:stop, {:error, Exception.message(e)}}
    end
  end

  def handle_events(events, _from, state) do
    errors_present = Enum.any?(events, &(DoneSignal.done?(&1) and DoneSignal.error?(&1)))
    filtered_events = Enum.filter(events, &want_signal?/1) |> Enum.reduce([], &combine_events/2)
    state = state
            |> Map.update(:all_events, filtered_events, &(&1 ++ filtered_events))
            |> process_output(errors_present)
    {:noreply, [], state}
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
    Logger.debug("Output sink for pipeline #{state.request.id} shutting down")
  end

  defp want_signal?(%DataSignal{}), do: true
  defp want_signal?(%DoneSignal{}=done) do
    DoneSignal.error?(done) == false
  end
  defp want_signal?(_), do: false

  def process_output(%__MODULE__{all_events: []}=state, _) do
    state
  end
  # Early exit
  def process_output(%__MODULE__{all_events: [%DoneSignal{}=done], policy: policy}=state, false) do
    done = %{done | template: @early_exit_template}
    send_to_owner(state)
    if policy in [:adapter, :adapter_owner] do
      early_exit_response(done, state)
    end
    success_event(state)
    Pipeline.teardown(state.pipeline)
    %{state | all_events: []}
  end
  def process_output(%__MODULE__{all_events: events, policy: policy}=state, _) do
    if DoneSignal.done?(List.last(events)) do
      send_to_owner(state)
      if policy in [:adapter, :adapter_owner] do
        Enum.each(events, &send_to_adapter(&1, state))
      end
      success_event(state)
      Pipeline.teardown(state.pipeline)
      %{state | all_events: []}
    else
      state
    end
  end

  defp combine_events(%DoneSignal{}=done, accum) do
    accum ++ [done]
  end
  defp combine_events(%DataSignal{}=data, []), do: [data]
  defp combine_events(%DataSignal{}=next_data, [%DataSignal{}=last_data]) do
    [%{last_data | data: List.wrap(last_data.data) ++ List.wrap(next_data.data),
       bundle_version_id: next_data.bundle_version_id, template: next_data.template,
       invocation: next_data.invocation}]
  end

  defp send_to_owner(%__MODULE__{all_events: events, policy: policy, owner: owner}=state) when policy in [:owner, :adapter_owner] do
    Process.send(owner, {:pipeline, state.request.id, {:output, events}}, [])
  end
  defp send_to_owner(_state), do: :ok

  defp send_to_adapter(%DoneSignal{}, state), do: state
  defp send_to_adapter(%DataSignal{}=signal, state) do
    Enum.each(state.destinations, &(send_to_adapter(&1, signal, state)))
  end

  defp send_to_adapter({type, targets}, signal, state) do
    output = output_for(type, signal, nil)
    Enum.each(targets, &ChatAdapter.send(state.conn, &1.provider, &1.room, output))
  end

  defp early_exit_response(%DoneSignal{}=signal, state) do
    # Synthesize a DataSignal from a DoneSignal so we can render templates
    data_signal = %DataSignal{template: signal.template,
                              data: [],
                              bundle_version_id: "common"}
    destinations = Destination.here(state.request)
    Enum.each(destinations, fn({type, destinations}) ->
      output = output_for(type, data_signal, "Terminated early")
      Enum.each(destinations, &ChatAdapter.send(&1.provider, &1.room, output)) end)
  end

  defp output_for(:chat, %DataSignal{}=signal, _message) do
    output   = signal.data
    bundle_vsn = signal.bundle_version_id
    template_name = signal.template
    if bundle_vsn == "common" do
      if template_name in ["error", "unregistered-user"] do
        # No "envelope" for these templates right now
        Evaluator.evaluate(template_name, output)
      else
        Evaluator.evaluate(template_name, Template.with_envelope(output))
      end
    else
      Evaluator.evaluate(bundle_vsn, template_name, Template.with_envelope(output))
    end
  end
  defp output_for(:trigger, signal, message) do
    envelope = %{status: "success",
                 pipeline_output: List.wrap(signal.data)}
    if message do
      Map.put(envelope, :message, message)
    else
      envelope
    end
  end
  defp output_for(:status_only, _signal, _message) do
    %{status: "success"}
  end

  defp success_event(state) do
    output = Enum.flat_map(state.all_events, fn(%DoneSignal{}) -> [];
                                               (%DataSignal{data: data}) -> [data] end)
    PipelineEvent.succeeded(state.request.id, state.started, output) |> Probe.notify
  end

end
