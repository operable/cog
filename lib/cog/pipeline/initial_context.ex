defmodule Cog.Pipeline.InitialContext do

  alias Experimental.GenStage
  alias Cog.Pipeline.DoneSignal

  @moduledoc ~s"""
  `GenStage` producer responsible for initiating pipeline execution.

  `InitialContext` begins with its `GenStage` demand set to `:accumulate`
  pausing the pipeline until it is fully constructed. Once the pipeline
  is ready calling `InitialContext.unlock/1` will begin processing.

  `GenStage.BroadcastDispatcher` is used to dispatch output from this stage.
  """

  use GenStage

  require Logger

  @type t :: %__MODULE__{
    request_id: String.t,
    context: [] | [Cog.Pipeline.DataSignal],
    done: boolean,
    pipeline: pid
  }
  defstruct [:context, :done, :pipeline, :request_id]

  @doc ~s"""
  Starts a new `InitialContext` process.

  ## Options
  * `:context` - Initial pipeline context. Either an empty list or a list of `Cog.Pipeline.DataSignal`. Required.
  * `:pipeline` - Pid of the parent pipeline. Required.
  * `:request_id` - Id of the originating request. Required.
  """
  @spec start_link(Keyword.t) :: {:ok, pid} | {:error, any}
  def start_link(opts) do
    case GenStage.start_link(__MODULE__, opts) do
      {:ok, pid} ->
        GenStage.demand(pid, :accumulate)
        {:ok, pid}
      error ->
        error
    end
  end

  @doc "Initiates pipeline processing."
  @spec unlock(pid) :: :ok
  def unlock(pid) do
    GenStage.demand(pid, :forward)
  end

  def init(opts) do
    try do
      pipeline = Keyword.fetch!(opts, :pipeline)
      Process.monitor(pipeline)
      {:producer, %__MODULE__{context: Keyword.fetch!(opts, :context),
                              done: false,
                              pipeline: pipeline,
                              request_id: Keyword.fetch!(opts, :request_id)},
       [dispatcher: GenStage.BroadcastDispatcher]}
    rescue
      e in KeyError ->
        {:stop, {:error, Exception.message(e)}}
    end
  end

  def handle_demand(_demand, %__MODULE__{done: false}=state) do
    {:noreply, state.context ++ [%DoneSignal{}], %{state | done: true}}
  end
  def handle_demand(_demand, %__MODULE__{done: true}=state) do
    {:noreply, [%DoneSignal{}], state}
  end

  def handle_info({:DOWN, _mref, _, pipeline, _}, %__MODULE__{pipeline: pipeline}=state) do
    Logger.debug("Initial context for pipeline #{state.request_id} shutting down")
    {:stop, :normal, state}
  end
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  def terminate(_reason, _state), do: :ok
end
