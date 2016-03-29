defmodule Cog.Queries.Relay do
  use Cog.Queries
  alias Cog.Repo

  def all() do
    from r in Relay,
    preload: [:groups]
  end

  def for_id(id) do
    all
    |> where([r], r.id == ^id)
  end

  def exists?(id) do
    Repo.one!(from r in Relay,
              where: r.id == ^id,
              select: count(r.id)) == 1
  end

end
