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

end
