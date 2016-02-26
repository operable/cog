defmodule Cog.Adapters.HipChat.Supervisor do
  use Supervisor

  def start_link() do
    Supervisor.start_link(__MODULE__, [])
  end

  def init(_) do
    children = [worker(Cog.Adapters.HipChat, []),
                worker(Cog.Adapters.HipChat.Connection, [])]
    supervise(children, strategy: :one_for_all)
  end
end
