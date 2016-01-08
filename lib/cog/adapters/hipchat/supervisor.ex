defmodule Cog.Adapters.HipChat.Supervisor do
  use Supervisor
  require Logger

  def start_link() do
    Supervisor.start_link(__MODULE__, [])
  end

  def init(_) do
    supervise([worker(Cog.Adapters.HipChat.Connection, [])], strategy: :one_for_all)
  end
end
