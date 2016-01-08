defmodule Cog.Queries.Bundles do

  use Cog.Queries

  alias Cog.Models.Bundle

  def bundle_details(id) do
    from b in Bundle,
    where: b.id == ^id,
    preload: [:commands, :namespace]
  end

  def bundle_summary(id) do
    from b in Bundle,
    where: b.id == ^id,
    preload: [:namespace]
  end

  def bundle_summaries() do
    from b in Bundle,
    preload: [:namespace]
  end

  def bundle_id_from_name(name) do
    from b in Bundle,
    where: b.name == ^name,
    select: b.id,
    limit: 1
  end
end
