# Lifted from https://github.com/phoenixframework/phoenix_ecto/blob/v1.2.0/lib/phoenix_ecto/json.ex
if Code.ensure_loaded?(Poison) do
  defimpl Poison.Encoder, for: Ecto.Changeset do
    def encode(changeset, opts) do
      encode_changeset(changeset)
      |> Poison.Encoder.encode(opts)
    end

    defp encode_changeset(%{errors: errors, changes: changes, types: types}) do
      errors
      |> Enum.reverse()
      |> merge_error_keys()
      |> merge_related_keys(changes, types)
    end

    defp merge_error_keys(errors) do
      Enum.reduce(errors, %{}, fn({k, v}, acc ) ->
        v = json_error(v)
        Map.update(acc, k, [v], &[v|&1])
      end)
    end

    defp merge_related_keys(map, changes, types) do
      Enum.reduce types, map, fn
        {field, {tag, %{cardinality: :many}}}, acc when tag in [:embed, :assoc] ->
          if changesets = Map.get(changes, field) do
            Map.put(acc, field, Enum.map(changesets, &encode_changeset/1))
          else
            acc
          end
        {field, {tag, %{cardinality: :one}}}, acc when tag in [:embed, :assoc] ->
          if changeset = Map.get(changes, field) do
            Map.put(acc, field, encode_changeset(changeset))
          else
            acc
          end
        {_, _}, acc ->
          acc
      end
    end

    defp json_error(msg) when is_binary(msg), do: msg
    defp json_error({msg, count: count}) when is_binary(msg) do
      String.replace(msg, "%{count}", to_string(count))
    end
  end
end
