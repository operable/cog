defmodule Cog.Command.Service.PipelineMonitor do
  alias Cog.Command.Service
  alias Cog.ETSWrapper
  require Logger

  @doc """
  Finds the pid of the pipeline executor corresponding to token provided which
  is then monitored and stored in the monitor table provided. Calling this
  function with the same token multiple times will only result in the creation
  of a single monitor.
  """
  def monitor_pipeline(monitor_table, token) do
    case Service.Tokens.process_for_token(token) do
      {:error, error} ->
        {:error, error}
      pid ->
        monitor_pipeline(monitor_table, token, pid)
    end
  end

  def monitor_pipeline(monitor_table, token, pid) do
    case ETSWrapper.lookup(monitor_table, pid) do
      {:ok, ^token} ->
        Logger.debug("Already monitoring #{inspect pid} for token #{inspect token}")
      {:error, :unknown_key} ->
        Logger.debug("Monitoring #{inspect pid} for token #{inspect token}")
        Process.monitor(pid)
        ETSWrapper.insert(monitor_table, pid, token)
    end
  end

  @doc """
  Removes the pipeline executor pid from the monitor table and removes any
  matching keys from the data table. Typically called when a pipeline executor
  process dies.
  """
  def cleanup_pipeline(monitor_table, data_table, pid, key_match) do
    Logger.debug("Pipeline #{inspect pid} is no longer alive; cleaning up after it")
    ETSWrapper.match_delete(data_table, {key_match, :_})
    ETSWrapper.delete(monitor_table, pid)
  end

  @doc """
  Runs through all pipeline executor pids in the monitor table and either
  monitors them if the process is alive, or cleans up after them if the process
  is dead. Typically called when restarting a service process. For more details
  about what the key_match_fun argument should return, see
  http://www.erlang.org/doc/man/ets.html#match-2
  """
  def account_for_existing_pipelines(monitor_table, data_table, key_match_fun \\ &(&1)) do
    ETSWrapper.each(monitor_table, fn pid, token ->
      case Process.alive?(pid) do
        true ->
          Logger.debug("Remonitoring #{inspect pid} for token #{inspect token}")
          Process.monitor(pid)
        false ->
          cleanup_pipeline(monitor_table, data_table, pid, key_match_fun.(token))
      end
    end)
  end

  @doc """
  Sends a `:dead_process_cleanup` message to the calling process at interval
  milliseconds in the future.
  """
  def schedule_dead_pipeline_cleanup(interval) do
    Logger.info ("Scheduling dead process cleanup for #{round(interval / 1000)} seconds from now")
    Process.send_after(self(), :dead_process_cleanup, interval)
  end

  @doc """
  Runs though all pipeline executor pids in the monitor table and cleans up
  after any dead processes. Used to remove any processes that died while the
  service process was restarting and we're not caught by a call to
  `account_for_existing_pipelines/2` during startup.
  """
  def dead_pipeline_cleanup(monitor_table, data_table) do
    ETSWrapper.each(monitor_table, fn pid, token ->
      unless Process.alive?(pid) do
        cleanup_pipeline(monitor_table, data_table, pid, {token, :_})
      end
    end)
  end
end
