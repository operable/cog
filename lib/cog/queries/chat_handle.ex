defmodule Cog.Queries.ChatHandle do
  use Cog.Queries

  def for_user_id(query \\ ChatHandle, user_id) do
    from ch in query,
    where: ch.user_id == ^user_id
  end
end
