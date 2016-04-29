defmodule Cog.Command.Service.Supervisor do
  use Supervisor
  require Logger

  alias Cog.Command.Service

  def start_link,
    do: Supervisor.start_link(__MODULE__, [], name: __MODULE__)

  def init(_) do
    token_table          = :ets.new(:token_table,          [:public])
    # token_monitor_table  = :ets.new(:token_monitor_table,  [:public])
    memory_table         = :ets.new(:memory_table,         [:public])
    memory_monitor_table = :ets.new(:memory_monitor_table, [:public])

    children = [# worker(Service.Tokens, [token_table, token_monitor_table]),
                worker(Service.Tokens, [token_table]),
                worker(Service.Memory, [memory_table, memory_monitor_table])]

    supervise(children, strategy: :one_for_one)
  end
end
