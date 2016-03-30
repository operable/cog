defmodule Cog.Queries.Repo do
  use Cog.Queries

  def count_by_id(model, id) do
    from m in model,
    where: m.id == ^id,
    select: count(m.id)
  end

end
