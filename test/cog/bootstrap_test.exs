defmodule Cog.Bootstrap.Test do
  use Cog.ModelCase
  use Cog.Models

  @admin_user %{
    "username" => "test-admin",
    "first_name" => "FirstName",
    "last_name" => "LastName",
    "email_address" => "admin@example.com"
  }

  setup context do
    if _ = context[:skip_bootstrap] do
      {:ok, bootstrapped: false}
    else
      {:ok, admin_user} = Cog.Bootstrap.bootstrap(@admin_user)
      admin_role = Cog.Repo.get_by!(Role, name: Cog.admin_role)
      admin_group = Cog.Repo.get_by!(Group, name: Cog.admin_group)
      {:ok, admin: admin_user, admin_role: admin_role, admin_group: admin_group, bootstrapped: true}
    end
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
    assert Repo.get_by!(Namespace, name: Cog.site_namespace)
  end

  test "the 'site' permission namespace contains no permissions" do
    ns = Repo.get_by!(Namespace, name: Cog.site_namespace) |> Repo.preload(:permissions)
    assert [] == ns.permissions
  end

  test "creates a default admin user", %{admin: admin} do
    ~w(username first_name last_name email_address)
    |> Enum.each(fn(field) -> assert Map.get(admin, String.to_existing_atom(field)) == Map.get(@admin_user, field) end)
  end

  test "admin role has all the embedded bundle permissions", %{admin_role: admin_role} do
    assert_permission_is_granted(admin_role, retrieve("#{Cog.embedded_bundle}:manage_users"))
    assert_permission_is_granted(admin_role, retrieve("#{Cog.embedded_bundle}:manage_roles"))
    assert_permission_is_granted(admin_role, retrieve("#{Cog.embedded_bundle}:manage_groups"))
    assert_permission_is_granted(admin_role, retrieve("#{Cog.embedded_bundle}:manage_permissions"))
    assert_permission_is_granted(admin_role, retrieve("#{Cog.embedded_bundle}:manage_commands"))
  end

  test "admin role is granted to admin group", %{admin_role: admin_role, admin_group: admin_group} do
    assert_role_is_granted(admin_group, admin_role)
  end

  test "admin user is member of admin group", %{admin: admin, admin_group: admin_group}  do
    assert_group_member_was_added(admin_group, Map.put(admin, :password, nil))
  end

  @tag :skip_bootstrap
  test "if the admin group exists, the system is considered bootstrapped" do
    refute Cog.Bootstrap.is_bootstrapped?

    Cog.Bootstrap.bootstrap(@admin_user)
    assert Cog.Models.Group |> Cog.Repo.one! |> Map.get(:name) == Cog.admin_group
    assert Cog.Bootstrap.is_bootstrapped?
  end

  test "the admin group cannot be deleted" do
    try do
      Cog.Models.Group |> Cog.Repo.delete_all
    rescue
      exception ->
        assert exception.postgres.message == "cannot modify admin group"
    end
  end

  test "the admin role cannot be deleted" do
    try do
      Cog.Models.Role |> Cog.Repo.delete_all
    rescue
      exception ->
        assert exception.postgres.message == "cannot modify admin role"
    end
  end

  test "the embedded bundle cannot be deleted" do
    try do
      Cog.Models.Bundle |> Cog.Repo.delete_all
    rescue
      exception ->
        assert exception.postgres.message == "cannot modify embedded bundle"
    end
  end

  test "installs embedded bundle" do
    assert Repo.get_by(Bundle, name: Cog.embedded_bundle)
  end

  defp retrieve(permission_name) do
    permission_name |> Cog.Queries.Permission.from_full_name |> Repo.one!
  end

end
