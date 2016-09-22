defmodule Cog.Queries.Repo do

  import Ecto.Query, only: [from: 2]

  def count_by_id(model, id) do
    from m in model,
    where: m.id == ^id,
    select: count(m.id)
  end

end
