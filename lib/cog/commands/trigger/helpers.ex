defmodule Cog.Command.Trigger.Helpers do

  def normalize_params(options) do
    options
    |> rekey("as-user", "as_user")
    |> rekey("timeout-sec", "timeout_sec")
  end

  defp rekey(map, old_key, new_key) do
    case Map.fetch(map, old_key) do
      {:ok, value} ->
        map
        |> Map.delete(old_key)
        |> Map.put(new_key, value)
      :error ->
        map
    end
  end
end
