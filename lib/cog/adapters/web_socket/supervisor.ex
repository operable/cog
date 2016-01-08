defmodule Cog.Adapters.WebSocket.Sup do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, [])
  end

  def init(_) do
    config = Application.get_env(:cog, Cog.Adapters.WebSocket)
    websocket_uri = fetch_required(config, :websocket_uri)
    bot_username  = fetch_required(config, :bot_username)

    children = [worker(Cog.Adapters.WebSocket.Server, [websocket_uri, bot_username])]
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
