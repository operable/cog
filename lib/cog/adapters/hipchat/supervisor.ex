defmodule Cog.Adapters.HipChat.Supervisor do
  use Supervisor
  alias Cog.Adapters.HipChat

  def start_link() do
    Supervisor.start_link(__MODULE__, [])
  end

  def init(_) do
    config = HipChat.Config.fetch_config!

    children = [worker(HipChat, []),
                worker(HipChat.API, [config]),
                worker(HipChat.Connection, [config])]

    supervise(children, strategy: :one_for_all)
  end
end
