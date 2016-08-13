defmodule Cog.Chat.HttpSupervisor do
  use Supervisor

  def start_link,
    do: Supervisor.start_link(__MODULE__, [], name: __MODULE__)

  def init(_) do
    children = [worker(Cog.Chat.HttpConnector, [])]
    supervise(children, strategy: :one_for_all)
  end
end
