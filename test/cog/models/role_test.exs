defmodule Cog.Models.Role.Test do
  use Cog.ModelCase

  alias Cog.Models.Role

  test "names are required" do
    changeset = Role.changeset(%Role{}, %{})
    assert {:name, "can't be blank"} in changeset.errors
  end

  test "names are unique" do
    {:ok, _role} = Repo.insert Role.changeset(%Role{}, %{"name" => "admin"})
    {:error, changeset} = Repo.insert Role.changeset(%Role{}, %{"name" => "admin"})
    assert {:name, "has already been taken"} in changeset.errors
  end

  test "admin role cannot be renamed" do
    Cog.Bootstrap.bootstrap
    role = Role |> Repo.get_by(name: Cog.admin_role)
    assert role.name == Cog.admin_role
    {:error, changeset} = Repo.update(Role.changeset(role, %{"name" => "not-cog-admin"}))
    assert {:name, "admin role may not be modified"} in changeset.errors
  end

end
