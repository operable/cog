defmodule Cog.Bootstrap.Test do
  use Cog.ModelCase
  use Cog.Models

  setup do
    {:ok, admin_user} = Cog.Bootstrap.bootstrap
    {:ok, admin: admin_user}
  end

  test "creates the embedded bundle permission namespace" do
    assert Repo.get_by!(Namespace, name: Cog.embedded_bundle)
  end

  test "creates core permissions in the embedded bundle namespace" do
    assert retrieve("#{Cog.embedded_bundle}:manage_users")
    assert retrieve("#{Cog.embedded_bundle}:manage_roles")
    assert retrieve("#{Cog.embedded_bundle}:manage_groups")
    assert retrieve("#{Cog.embedded_bundle}:manage_permissions")
    assert retrieve("#{Cog.embedded_bundle}:manage_commands")
  end

  test "creates the 'site' permission namespace" do
    assert Repo.get_by!(Namespace, name: "site")
  end

  test "the 'site' permission namespace contains no permissions" do
    ns = Repo.get_by!(Namespace, name: "site") |> Repo.preload(:permissions)
    assert [] == ns.permissions
  end

  test "creates an admin user", %{admin: admin} do
    assert admin.username == "admin"
    assert admin.first_name == "Cog"
    assert admin.last_name == "Administrator"
    assert admin.email_address == "cog@localhost"
  end

  test "admin user has all the embedded bundle permissions", %{admin: admin} do
    assert_permission_is_granted(admin, retrieve("#{Cog.embedded_bundle}:manage_users"))
    assert_permission_is_granted(admin, retrieve("#{Cog.embedded_bundle}:manage_roles"))
    assert_permission_is_granted(admin, retrieve("#{Cog.embedded_bundle}:manage_groups"))
    assert_permission_is_granted(admin, retrieve("#{Cog.embedded_bundle}:manage_permissions"))
    assert_permission_is_granted(admin, retrieve("#{Cog.embedded_bundle}:manage_commands"))
  end

  test "if the admin user exists, the system is considered bootstrapped", %{admin: admin} do
    assert Cog.Bootstrap.is_bootstrapped?

    # Delete the admin, and we should no longer be "bootstrapped"
    {:ok, _} = Repo.delete(admin)
    refute Cog.Bootstrap.is_bootstrapped?
  end

  test "installs embedded bundle" do
    assert Repo.get_by(Bundle, name: Cog.embedded_bundle)
  end

  defp retrieve(permission_name) do
    permission_name |> Cog.Queries.Permission.from_full_name |> Repo.one!
  end

end
