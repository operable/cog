defmodule Cog.Adapters.Slack.Supervisor do
  use Supervisor

  import Cog.Helpers, only: [ensure_integer: 1]

  def start_link do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    config = Application.get_env(:cog, Cog.Adapters.Slack)

    api_token = fetch_required(config, :api_token)
    cache_ttl = ensure_integer(Keyword.get(config, :api_cache_ttl))

    children = [worker(Cog.Adapters.Slack, []),
                worker(Cog.Adapters.Slack.RTMConnector, [api_token]),
                worker(Cog.Adapters.Slack.API, [api_token, cache_ttl])]
    supervise(children, strategy: :one_for_all)
  end

  defp fetch_required(config, key) do
    case Keyword.get(config, key) do
      nil ->
        raise ArgumentError, "missing #{inspect key} configuration in " <>
                             "config #{inspect :cog}, #{inspect Cog.Adapters.Slack}"
      value ->
        value
    end
  end
end
