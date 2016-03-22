defmodule Cog.Queries.Alias do
  use Cog.Queries
  import Ecto.Query, only: [from: 2, where: 2]
  alias Cog.Models.UserCommandAlias
  alias Cog.Models.SiteCommandAlias

  def for_user(query \\ UserCommandAlias, user_id) do
    from a in query,
    where: a.user_id == ^user_id
  end

  def matching(query \\ UserCommandAlias, pattern) do
    from a in query,
    where: like(a.name, ^pattern)
  end

  def user_alias_by_name(%Cog.Models.User{id: user_id}, alias_name) do
    from ua in UserCommandAlias,
    where: ua.name == ^alias_name,
    where: ua.user_id == ^user_id
  end

  def site_alias_by_name(name),
    do: SiteCommandAlias |> where(name: ^name)
end
