defmodule Cog.DBSup do

  require Logger
  use Supervisor

  alias Cog.Repository.PipelineHistory

  def start_link() do
    case Supervisor.start_link(__MODULE__, []) do
      {:ok, pid} ->
        # Update orphaned pipeline statuses after Cog.Repo has been started.
        # This ensures we have a (relatively) consistent view
        # of pipelines and their status after we start up.
        count = PipelineHistory.update_orphans()
        if count > 0 do
          Logger.warn("Updated #{count} orphaned pipeline records.")
        end
        {:ok, pid}
      error ->
        error
    end
  end

  def init(_) do
    children = [worker(Cog.Repo, [])]
    {:ok, {%{strategy: :one_for_one, intensity: 10, period: 60}, children}}
  end

end
