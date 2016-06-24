defmodule Cog.Util.Hash do

  @doc """
  Computes a deterministic hash value for a given data structure.
  Maps are traversed in ascending lexographic order
  """
  def compute_hash(data, type \\ :sha256) do
    :crypto.hash_init(type)
    |> hash_value(data)
    |> :crypto.hash_final
    |> Base.encode16
    |> String.downcase
  end

  defp hash_value(ctx, value) when is_map(value) do
    # Disambiguates empty map from list
    ctx = hash_value(ctx, "m")
    keys = Enum.sort(Map.keys(value))
    Enum.reduce(keys, ctx, fn(key, ctx) -> hash_value(ctx, key, Map.fetch!(value, key)) end)
  end
  defp hash_value(ctx, value) when is_list(value) do
    Enum.reduce(value, ctx, fn(v, ctx) -> hash_value(ctx, v) end)
  end
  defp hash_value(ctx, value) do
    value = Poison.encode!(value)
    :crypto.hash_update(ctx, value)
  end

  defp hash_value(ctx, key, value) do
    ctx
    |> hash_value(key)
    |> hash_value(value)
  end


end
