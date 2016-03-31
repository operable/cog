defmodule Cog.Relay.RelaySup do
  use Supervisor

  def start_link,
    do: Supervisor.start_link(__MODULE__, [], name: __MODULE__)

  def init([]) do
    children = [worker(Cog.Relay.Relays, []),
                worker(Cog.Relay.Info, []),
                supervisor(Cog.Bundle.Embedded, [])]
    supervise(children, strategy: :rest_for_one)
  end

end
