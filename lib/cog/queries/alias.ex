defmodule Cog.Queries.Alias do
  use Cog.Queries
  import Ecto.Query, only: [from: 2, where: 2]

  def user_matching(pattern, handle, provider) do
    from a in UserCommandAlias,
    join: u in assoc(a, :user),
    join: ch in assoc(u, :chat_handles),
    join: cp in assoc(ch, :chat_provider),
    where: ch.handle == ^handle,
    where: cp.name == ^provider,
    where: like(a.name, ^pattern)
  end

  def site_matching(pattern) do
    from a in SiteCommandAlias,
    where: like(a.name, ^pattern)
  end

  def user_aliases(handle, provider) do
    from a in UserCommandAlias,
    join: u in assoc(a, :user),
    join: ch in assoc(u, :chat_handles),
    join: cp in assoc(ch, :chat_provider),
    where: ch.handle == ^handle,
    where: cp.name == ^provider
  end

  def site_aliases() do
    from a in SiteCommandAlias,
    select: a
  end

  def user_alias_by_name(%Cog.Models.User{id: user_id}, alias_name) do
    from ua in UserCommandAlias,
    where: ua.name == ^alias_name,
    where: ua.user_id == ^user_id
  end

  def site_alias_by_name(name),
    do: SiteCommandAlias |> where(name: ^name)

end
