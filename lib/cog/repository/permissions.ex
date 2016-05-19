defmodule Cog.Repository.Permissions do

  alias Cog.Models.Permission
  alias Cog.Repo

  @doc """
  Creates a new permission in the site bundle. All permissions created
  directly by users are of this type.
  """
  def create_permission(permission_name) do
    create_permission(Cog.Repository.Bundles.site_bundle_version,
                      permission_name)
  end

  # TODO: Consider having this code create the permission if it
  # doesn't exist, but always linking the permission to the bundle
  # version. That way, `link_permission_to_bundle_version` can be
  # private.
  @doc """
  Create a permission in an arbitrary bundle. A bundle version is
  provided in order to associate a given permission with each bundle
  version it comes from.
  """
  def create_permission(bundle_version, permission_name) do
    case bundle_version.bundle
    |> Ecto.Model.build(:permissions)
    |> Permission.changeset(%{name: permission_name})
    |> Repo.insert do
      {:ok, permission} ->
        link_permission_to_bundle_version(bundle_version, permission)
        {:ok, Repo.preload(permission, :bundle)}
      {:error, _}=error ->
        error
    end
  end

  def link_permission_to_bundle_version(bundle_version, permission),
    do: Cog.Models.JoinTable.associate(bundle_version, permission)

end
