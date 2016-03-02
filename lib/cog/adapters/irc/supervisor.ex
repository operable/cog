defmodule Cog.Adapters.IRC.Supervisor do
  use Supervisor
  alias Cog.Adapters.IRC

  def start_link do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    config = Application.get_env(:cog, IRC)
    host = Keyword.get(config, :host)
    port = Keyword.get(config, :port) |> String.to_integer
    nick = Keyword.get(config, :nick)
    channel = Keyword.get(config, :channel)

    {:ok, client} = ExIrc.start_client!

    children = [worker(IRC, []),
                worker(IRC.Connection, [client, host, port, nick, channel])]

    supervise(children, strategy: :one_for_all)
  end
end
