defmodule Cog.Util.Ecto do

  require Logger

  @doc """
  Sanely logs Ecto query output
  """
  def log(entry) do
    IO.puts("here")
    case entry.result do
      {:ok, _} ->
        Logger.log(:debug, "Query: #{entry.query}, Params: #{inspect entry.params}, " ++
          "Query Time: #{entry.query_time}, Queue Time: #{entry.queue_time}")
      {:error, error} ->
        Logger.log(:warn, "Query: #{entry.query}, Params: #{inspect entry.params}, " ++
          "Error: #{inspect error}, Query Time: #{entry.query_time}, Queue Time: #{entry.queue_time}")
    end
    entry
  end

end
