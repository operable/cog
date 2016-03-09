defmodule Cog.Adapters.IRC.Supervisor do
  use Supervisor
  alias Cog.Adapters.IRC

  def start_link do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    config = IRC.Config.fetch_config!
    {:ok, client} = ExIrc.start_client!

    children = [worker(IRC, []),
                worker(IRC.Connection, [[client: client, config: config]])]
    supervise(children, strategy: :one_for_all)
  end
end
