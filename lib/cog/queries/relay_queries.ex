defmodule Cog.Queries.Relay do
  use Cog.Queries

  def all() do
    from r in Relay,
    preload: [groups: :bundles]
  end

  def for_id(id) do
    all
    |> where([r], r.id == ^id)
  end

end
