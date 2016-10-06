defmodule Cog.CoreSup do
  require Logger
  use Supervisor

  def start_link() do
    Supervisor.start_link(__MODULE__, [])
  end

  def init(_) do
    children = [worker(Cog.TokenReaper, []),
                supervisor(Cog.Util.CacheSup, []),
                supervisor(Cog.Relay.RelaySup, []),
                supervisor(Cog.Command.CommandSup, []),
                supervisor(Cog.Endpoint, []),
                supervisor(Cog.TriggerEndpoint, []),
                supervisor(Cog.ServiceEndpoint, []),
                supervisor(Cog.ChatSup, [])]
    {:ok, {%{strategy: :one_for_one, intensity: 10, period: 60}, children}}
  end

end
