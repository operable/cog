defmodule Cog.Adapters.Test.Supervisor do
  use Supervisor

  def start_link() do
    Supervisor.start_link(__MODULE__, [])
  end

  def init(_) do
    children = [worker(Cog.Adapters.Test, [])]
    supervise(children, strategy: :one_for_all)
  end
end
