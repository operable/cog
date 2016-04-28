defmodule Cog.Command.Service.Supervisor do
  use Supervisor
  require Logger

  alias Cog.Command.Service

  def start_link,
    do: Supervisor.start_link(__MODULE__, [], name: __MODULE__)

  def init(_) do
    token_tid = new_token_table
    Logger.info("Created service token table with TID #{inspect token_tid}")

    memory_tid = new_memory_table
    Logger.info("Created memory service table with TID #{inspect memory_tid}")

    children = [
      worker(Service.Tokens, [token_tid]),
      worker(Service.Memory, [memory_tid])
    ]
    supervise(children, strategy: :one_for_one)
  end

  ########################################################################

  # Create ETS table for tokens
  defp new_token_table,
    do: :ets.new(:token_table, [:public])

  defp new_memory_table,
    do: :ets.new(:memory_table, [:public])

end
