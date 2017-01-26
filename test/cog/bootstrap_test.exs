defmodule Cog.Bootstrap.Test do
  use Cog.ModelCase
  alias Cog.Models.{Bundle, BundleVersion, Group, Role}

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
      admin_role = Repo.get_by!(Role, name: Cog.Util.Misc.admin_role)
      admin_group = Repo.get_by!(Group, name: Cog.Util.Misc.admin_group)
      {:ok, admin: admin_user, admin_role: admin_role, admin_group: admin_group, bootstrapped: true}
    end
  end

  test "creates the embedded bundle" do
    assert Repo.get_by!(Bundle, name: Cog.Util.Misc.embedded_bundle)
  end

  test "creates core permissions in the embedded bundle namespace" do
    assert retrieve("#{Cog.Util.Misc.embedded_bundle}:manage_users")
    assert retrieve("#{Cog.Util.Misc.embedded_bundle}:manage_roles")
    assert retrieve("#{Cog.Util.Misc.embedded_bundle}:manage_groups")
    assert retrieve("#{Cog.Util.Misc.embedded_bundle}:manage_permissions")
    assert retrieve("#{Cog.Util.Misc.embedded_bundle}:manage_commands")
  end

  test "creates the site bundle" do
    assert Repo.get_by!(Bundle, name: Cog.Util.Misc.site_namespace)
  end

  test "creates single site bundle version" do
    bundle = Repo.get_by!(Bundle, name: Cog.Util.Misc.site_namespace) |> Repo.preload(:versions)

    {:ok, version} = Version.parse("0.0.0")
    assert [%BundleVersion{version: ^version}] = bundle.versions
  end

  test "the 'site' bundle contains no permissions" do
    bundle = Repo.get_by!(Bundle, name: Cog.Util.Misc.site_namespace) |> Repo.preload(:permissions)
    assert [] == bundle.permissions
  end

  test "creates a default admin user", %{admin: admin} do
    ~w(username first_name last_name email_address)
    |> Enum.each(fn(field) -> assert Map.get(admin, String.to_existing_atom(field)) == Map.get(@admin_user, field) end)
  end

  test "admin role has all the embedded bundle permissions", %{admin_role: admin_role} do
    assert_permission_is_granted(admin_role, retrieve("#{Cog.Util.Misc.embedded_bundle}:manage_users"))
    assert_permission_is_granted(admin_role, retrieve("#{Cog.Util.Misc.embedded_bundle}:manage_roles"))
    assert_permission_is_granted(admin_role, retrieve("#{Cog.Util.Misc.embedded_bundle}:manage_groups"))
    assert_permission_is_granted(admin_role, retrieve("#{Cog.Util.Misc.embedded_bundle}:manage_permissions"))
    assert_permission_is_granted(admin_role, retrieve("#{Cog.Util.Misc.embedded_bundle}:manage_commands"))
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
    assert Group |> Repo.one! |> Map.get(:name) == Cog.Util.Misc.admin_group
    assert Cog.Bootstrap.is_bootstrapped?
  end

  test "the admin group cannot be deleted" do
    try do
      admin_group = Repo.get_by!(Group, name: Cog.Util.Misc.admin_group)
      Repo.delete(admin_group)
    rescue
      exception ->
        assert %Ecto.ConstraintError{constraint: "group_roles_group_id_fkey"} = exception
    end
  end

  test "the admin role cannot be deleted" do
    try do
      admin_role = Repo.get_by!(Role, name: Cog.Util.Misc.admin_group)
      Repo.delete(admin_role)
    rescue
      exception ->
        assert %Ecto.ConstraintError{constraint: "group_roles_role_id_fkey"} = exception
    end
  end

  test "the embedded bundle cannot be deleted" do
    try do
      embedded = Repo.get_by!(Bundle, name: Cog.Util.Misc.embedded_bundle)
      Cog.Repository.Bundles.delete(embedded)
    rescue
      exception ->
        assert exception.postgres.message == "cannot modify embedded bundle"
    end
  end

  test "installs embedded bundle" do
    assert Repo.get_by(Bundle, name: Cog.Util.Misc.embedded_bundle)
  end

  defp retrieve(permission_name) do
    permission_name |> Cog.Queries.Permission.from_full_name |> Repo.one!
  end

end
