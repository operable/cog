defmodule Cog.Repository.Roles do
  alias Cog.Models.Role
  alias Cog.Repo

  def by_name(name),
    do: Repo.get_by(Role, name: name)

  def grant(%Role{}=role, one_or_more_permissions) do
    permissions = List.wrap(one_or_more_permissions)
    Enum.each(permissions, &Permittable.grant_to(role, &1))
    Cog.Command.PermissionsCache.reset_cache
    preload(role)
  end

  def revoke(%Role{}=role, one_or_more_permissions) do
    permissions = List.wrap(one_or_more_permissions)
    Enum.each(permissions, &Permittable.revoke_from(role, &1))
    Cog.Command.PermissionsCache.reset_cache
    preload(role)
  end

  ########################################################################

  defp preload(role),
    do: Repo.preload(role, [permissions: :bundle])

end
