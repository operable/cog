defmodule Cog.Models.Permission.Test do
  use Cog.ModelCase
  alias Cog.Models.Permission

  doctest Permission

  setup do
    {:ok, [role: role("admin"),
           permission: permission("test:do_stuff")]}
  end

  test "deleting a permission granted to a role", %{role: role, permission: permission} do :ok = Permittable.grant_to(role, permission)
    :ok = Permittable.grant_to(role, permission)
    changeset = Permission.changeset(permission, %{})
    assert {:error, changeset} = Repo.delete(changeset)
    assert [id: {"cannot delete permission that has been granted to a role", []}] = changeset.errors
  end
end
