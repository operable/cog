defmodule Cog.Repository.Roles do
  alias Cog.Models.Role
  alias Cog.Repo

  def new(name) do
    new_role = %Role{}
    |> Role.changeset(%{name: name})
    |> Repo.insert

    case new_role do
      {:ok, role} ->
        {:ok, preload(role)}
      error ->
        error
    end
  end

  def delete(%Role{name: unquote(Cog.admin_role)=name}),
    do: {:error, {:protected_role, name}}
  def delete(%Role{}=role),
    do: Repo.delete(role)

  def all,
    do: Repo.all(Role) |> preload

  @spec by_name(String.t) :: %Role{} | nil
  def by_name(name) do
    with(%Role{}=role <- Repo.get_by(Role, name: name)) do
      preload(role)
    end
  end

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

  # We don't (yet) have need of general update
  def rename(%Role{name: unquote(Cog.admin_role)=name}, _),
    do: {:error, {:protected_role, name}}
  def rename(%Role{}=role, new_name) do
    case role
    |> Role.changeset(%{name: new_name})
    |> Repo.update do
      {:ok, role} ->
        {:ok, preload(role)}
      {:error, _}=error ->
        error
    end
  end

  ########################################################################

  defp preload(role_or_roles),
    do: Repo.preload(role_or_roles, [permissions: :bundle])

end
