defmodule Cog.Queries.RelayGroup do

  import Ecto.Query, only: [from: 2, where: 3]
  alias Cog.Models.RelayGroup

  def all() do
    from rg in RelayGroup,
    preload: [:relays, bundles: :versions]
  end

  def for_id(id) do
    all
    |> where([rg], rg.id == ^id)
  end

end
