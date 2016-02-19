defmodule Cog.Queries.Alias do
  use Cog.Queries

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

  def user_alias_by_name(name) do
    from a in UserCommandAlias,
    where: a.name == ^name,
    select: a
  end

  def site_alias_by_name(name) do
    from a in SiteCommandAlias,
    where: a.name == ^name,
    select: a
  end

end
