defmodule Cog.Adapters.Slack.Supervisor do
  use Supervisor
  alias Cog.Adapters.Slack

  def start_link do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    config = Slack.Config.fetch_config!
    children = [worker(Cog.Adapters.Slack, []),
                worker(Cog.Adapters.Slack.RTMConnector, [config]),
                worker(Cog.Adapters.Slack.API, [config])]
    supervise(children, strategy: :one_for_all)
  end
end
