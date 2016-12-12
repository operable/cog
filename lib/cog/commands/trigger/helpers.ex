defmodule Cog.Command.Trigger.Helpers do

  def normalize_params(options) do
    options
    |> rekey("as-user", "as_user")
    |> rekey("timeout-sec", "timeout_sec")
  end

  # We leverage the TriggerView from the API in order to expose the
  # trigger's invocation URL to users.
  def convert(data) when is_list(data),
    do: Enum.map(data, &convert/1)
  def convert(%Cog.Models.Trigger{}=trigger) do
    Cog.V1.TriggerView.render("trigger.json",
                              %{trigger: trigger})
  end
  def convert(other),
    do: other

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
