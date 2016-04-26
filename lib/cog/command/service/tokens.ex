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
  require Logger

  defstruct [:tid]

  @doc """
  Start the #{inspect __MODULE__} service, pointed to an existing
  public ETS table identified by `tid`.
  """
  def start_link(tid),
    do: GenServer.start_link(__MODULE__, [tid], name: __MODULE__)

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

  def init([tid]) do
    Logger.info("Starting with token table #{inspect tid}")
    {:ok, %__MODULE__{tid: tid}}
  end

  def handle_call(:new, {pid, _ref}, %__MODULE__{tid: tid}=state) do
    token   = generate_token
    monitor = :erlang.monitor(:process, pid)
    Logger.debug("Generated token `#{inspect token}` for process `#{inspect pid}`, monitored via `#{inspect monitor}`")

    :ets.insert(tid, {token, pid})
    :ets.insert(tid, {monitor, token})

    {:reply, token, state}
  end
  def handle_call({:process, token}, _from, %__MODULE__{tid: tid}=state) do
    reply = case :ets.lookup(tid, token) do
              [{^token, process_pid}] ->
                process_pid
              [] ->
                {:error, :unknown_token}
            end
    {:reply, reply, state}
  end

  def handle_info({:'DOWN', monitor_ref, :process, pid, reason}, %__MODULE__{tid: tid}=state) do
    Logger.debug("Process #{inspect pid} went down (#{inspect reason}); invalidating its token")
    case :ets.lookup(tid, monitor_ref) do
      [{^monitor_ref, token}] ->
        :ets.delete(tid, token)
        :ets.delete(tid, monitor_ref)
      [] ->
        Logger.warn("Unknown monitor ref #{inspect monitor_ref} for pid #{inspect pid} going down for #{inspect reason}")
    end
    {:noreply, state}
  end

  ########################################################################
  # Helper Functions

  defp generate_token,
    do: UUID.uuid4(:hex)

end
