defmodule Cog.Queries.Bundles do

  import Ecto.Query, only: [from: 2, where: 3]

  alias Cog.Models.Bundle

  def all do
    from b in Bundle,
    preload: [:permissions, commands: [rules: [permissions: :bundle]], relay_groups: [:relays]]
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
