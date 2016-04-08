defmodule Cog.Adapters.Http.Supervisor do
  use Supervisor

  def start_link,
    do: Supervisor.start_link(__MODULE__, [], name: __MODULE__)

  def init(_) do
    children = [worker(Cog.Adapters.Http.AdapterBridge, []),
                worker(Cog.Adapters.Http, [])]
    supervise(children, strategy: :one_for_all)
  end
end
