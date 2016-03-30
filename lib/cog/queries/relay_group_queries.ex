defmodule Cog.Queries.RelayGroup do
  use Cog.Queries

  def all() do
    from rg in RelayGroup,
    preload: [:relays, :bundles]
  end

  def for_id(id) do
    all
    |> where([rg], rg.id == ^id)
  end

end
