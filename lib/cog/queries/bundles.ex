defmodule Cog.Queries.Bundles do

  use Cog.Queries

  alias Cog.Models.Bundle

  def all do
    from b in Bundle,
    preload: [:commands, :relay_groups, :namespace]
  end

  def for_id(id) do
    all
    |> where([b], b.id == ^id)
  end

  def bundle_id_from_name(name) do
    from b in Bundle,
    where: b.name == ^name,
    select: b.id,
    limit: 1
  end

end
