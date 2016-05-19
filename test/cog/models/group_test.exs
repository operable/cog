defmodule Cog.Models.Group.Test do
  use Cog.ModelCase

  alias Cog.Models.Group

  test "names are required" do
    changeset = Group.changeset(%Group{}, %{})
    assert {:name, "can't be blank"} in changeset.errors
  end

  test "names are unique" do
    {:ok, _group} = Repo.insert Group.changeset(%Group{}, %{"name" => "admin"})
    {:error, changeset} = Repo.insert Group.changeset(%Group{}, %{"name" => "admin"})
    assert {:name, "The group name is already in use."} in changeset.errors
  end

  test "admin group cannot be renamed" do
    Cog.Bootstrap.bootstrap
    group = Group |> Repo.get_by(name: Cog.admin_group)
    assert group.name == Cog.admin_group
    {:error, changeset} = Repo.update(Group.changeset(group, %{"name" => "not-cog-admin"}))
    assert {:name, "admin group may not be modified"} in changeset.errors
  end

end
