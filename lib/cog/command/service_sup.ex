defmodule Cog.Command.Service.Supervisor do
  use Supervisor

  alias Cog.Command.Service

  def start_link,
    do: Supervisor.start_link(__MODULE__, [], name: __MODULE__)

  def init(_) do
    token_table          = :ets.new(:token_table,          [:public])
    token_monitor_table  = :ets.new(:token_monitor_table,  [:public])
    memory_table         = :ets.new(:memory_table,         [:public])
    memory_monitor_table = :ets.new(:memory_monitor_table, [:public])
    data_path            = data_path

      Application.get_env(:cog, Cog.Command.Service, [])[:data_path]

    children = [worker(Service.Tokens, [token_table,  token_monitor_table]),
                worker(Service.DataStore, [data_path]),
                worker(Service.Memory, [memory_table, memory_monitor_table])]

    supervise(children, strategy: :one_for_one)
  end

  def data_path do
    Application.fetch_env!(:cog, Cog.Command.Service)
    |> Keyword.fetch!(:data_path)
  end
end
