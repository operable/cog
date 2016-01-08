defmodule Cog.Adapters.Test.Supervisor do
  use Supervisor
  require Logger

  def start_link() do
    Supervisor.start_link(__MODULE__, [])
  end

  def init(_) do
    supervise([worker(Cog.Adapters.Test.Recorder, [])], strategy: :one_for_all)
  end
end
