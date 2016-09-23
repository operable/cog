defmodule Cog.Queries.Relay do

  import Ecto.Query, only: [from: 2, where: 3]
  alias Cog.Models.Relay

  def all() do
    from r in Relay,
    preload: [groups: :bundles]
  end

  def for_id(id) do
    all
    |> where([r], r.id == ^id)
  end

end
