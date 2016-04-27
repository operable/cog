defmodule Cog.Models.Role.Test do
  use Cog.ModelCase

  alias Cog.Models.JoinTable
  alias Cog.Models.Role
  alias Cog.Queries

  setup context do
    if _ = context[:bootstrap] do
      Cog.Bootstrap.bootstrap

      admin_role = Role |> Repo.get_by(name: Cog.admin_role)
      assert admin_role.name == Cog.admin_role

      admin_perms = Queries.Permission.from_bundle_name(Cog.embedded_bundle) |> Repo.all

      {:ok, admin_role: admin_role, admin_perms: admin_perms, bootstrapped: true}
    else
      {:ok, bootstrapped: false}
    end
  end

  test "names are required" do
    changeset = Role.changeset(%Role{}, %{})
    assert {:name, "can't be blank"} in changeset.errors
  end

  test "names are unique" do
    {:ok, _role} = Repo.insert Role.changeset(%Role{}, %{"name" => "admin"})
    {:error, changeset} = Repo.insert Role.changeset(%Role{}, %{"name" => "admin"})
    assert {:name, "has already been taken"} in changeset.errors
  end

  @tag :bootstrap
  test "admin role cannot be renamed", %{admin_role: admin_role} do
    {:error, changeset} = Repo.update(Role.changeset(admin_role, %{"name" => "not-cog-admin"}))
    assert {:name, "admin role may not be modified"} in changeset.errors
  end

  @tag :bootstrap
  test "embedded permissions cannot be removed from the admin role (Model)", %{admin_role: admin_role, admin_perms: admin_perms} do
    Enum.each(admin_perms, fn(perm) ->
      assert Permittable.revoke_from(admin_role, perm) ==
        {:error, "cannot remove embedded permissions from admin role"}
    end)
  end

  @tag :bootstrap
  test "embedded permissions cannot be removed from the admin role (DB)", %{admin_role: admin_role, admin_perms: [perm|_]} do
    error = catch_error(JoinTable.dissociate(admin_role, perm))
    assert error.postgres.message == "cannot remove embedded permissions from admin role"
  end

end
