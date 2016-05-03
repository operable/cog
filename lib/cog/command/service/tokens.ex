defmodule Cog.Command.Service.Tokens do
  @moduledoc """
  Manages tokens used to mediate access to services. Each executor
  process will obtain a unique, process-specific token, which commands
  can use to access the service infrastructure.

  Each token is associated to the calling process, which is also
  monitored. When the process exits or crashes, the token is
  automatically invalidated, preventing its further use.
  """

  use GenServer
  import Cog.Command.Service.PipelineMonitor
  alias Cog.ETSWrapper
  require Logger

  @dead_pipeline_cleanup_interval 30000 # 30 seconds

  defstruct [:token_table, :monitor_table]

  @doc """
  Starts the #{inspect __MODULE__} service. Accepts two public ets table
  ids: one for storing tokens and keeping track of monitored pids.
  """
  def start_link(token_table, monitor_table),
    do: GenServer.start_link(__MODULE__, [token_table, monitor_table], name: __MODULE__)

  @doc """
  Create a new service token, registered to the calling process.
  """
  def new,
    do: GenServer.call(__MODULE__, :new)

  @doc """
  Given a service token, obtain the process that registered it.
  """
  def process_for_token(token),
    do: GenServer.call(__MODULE__, {:process, token})

  ########################################################################
  # GenServer Implementation

  def init([token_table, monitor_table]) do
    account_for_existing_pipelines(monitor_table, token_table)
    schedule_dead_pipeline_cleanup(@dead_pipeline_cleanup_interval)

    state = %__MODULE__{token_table: token_table, monitor_table: monitor_table}
    {:ok, state}
  end

  def handle_call(:new, {pid, _ref}, state) do
    result = case ETSWrapper.lookup(state.monitor_table, pid) do
      {:ok, _pid} ->
        {:error, :token_already_exists}
      {:error, :unknown_key} ->
        token = generate_token()
        ETSWrapper.insert(state.token_table, token, pid)
        monitor_pipeline(state.monitor_table, token, pid)
        token
    end

    {:reply, result, state}
  end

  def handle_call({:process, token}, _from, state) do
    result = case ETSWrapper.lookup(state.token_table, token) do
      {:ok, pid} ->
        pid
      {:error, :unknown_key} ->
        {:error, :unknown_token}
    end

    {:reply, result, state}
  end

  def handle_info({:DOWN, _monitor_ref, :process, pid, _reason}, state) do
    case ETSWrapper.lookup(state.monitor_table, pid) do
      {:ok, token} ->
        cleanup_pipeline(state.monitor_table, state.token_table, pid, token)
      {:error, :unknown_key} ->
        Logger.warn("Unknown pid #{inspect pid} was monitored; ignoring")
    end

    {:noreply, state}
  end

  def handle_info(:dead_process_cleanup, state) do
    dead_pipeline_cleanup(state.monitor_table, state.token_table)
    schedule_dead_pipeline_cleanup(@dead_pipeline_cleanup_interval)

    {:noreply, state}
  end

  ########################################################################
  # Helper Functions

  defp generate_token,
    do: UUID.uuid4(:hex)

end
