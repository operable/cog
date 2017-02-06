defmodule Cog.Repository.Roles do
  alias Cog.Models.Role
  alias Cog.Repo
  alias Cog.Pipeline.PermissionsCache

  def new(name) when is_binary(name),
    do: new(%{"name" => name})
  def new(params) do
    new_role = %Role{}
    |> Role.changeset(params)
    |> Repo.insert

    case new_role do
      {:ok, role} ->
        {:ok, preload(role)}
      error ->
        error
    end
  end

  def delete(%Role{name: unquote(Cog.Util.Misc.admin_role)=name}),
    do: {:error, {:protected_role, name}}
  def delete(%Role{}=role),
    do: role |> Role.changeset(:delete) |> Repo.delete

  def all,
    do: Repo.all(Role) |> preload

  @spec by_name(String.t) :: %Role{} | nil
  def by_name(name) do
    with(%Role{}=role <- Repo.get_by(Role, name: name)) do
      preload(role)
    end
  end

  @spec by_id!(String.t) :: %Role{} | :no_return
  def by_id!(id) do
    role = Repo.get!(Role, id)
    preload(role)
  end

  def grant(%Role{}=role, one_or_more_permissions) do
    permissions = List.wrap(one_or_more_permissions)
    Enum.each(permissions, &Permittable.grant_to(role, &1))
    PermissionsCache.reset_cache
    preload(role)
  end

  def revoke(%Role{}=role, one_or_more_permissions) do
    permissions = List.wrap(one_or_more_permissions)
    Enum.each(permissions, &Permittable.revoke_from(role, &1))
    PermissionsCache.reset_cache
    preload(role)
  end

  def update(%Role{}=role, params) do
    case role
    |> Role.changeset(params)
    |> Repo.update do
      {:ok, role} ->
        {:ok, preload(role)}
      {:error, _}=error ->
        error
    end
  end

  def rename(%Role{name: unquote(Cog.Util.Misc.admin_role)=name}, _),
    do: {:error, {:protected_role, name}}
  def rename(%Role{}=role, new_name),
    do: update(role, %{"name" => new_name})

  ########################################################################

  defp preload(role_or_roles),
    do: Repo.preload(role_or_roles, [permissions: :bundle, group_grants: :group])

end
