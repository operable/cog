defmodule Cog.Queries.Permission.Test do
  use Cog.ModelCase

  setup do
    # This is our test permission
    permission = permission("s3:create")

    # Now create some other permissions so we can ensure that our
    # query selectivity is correct

    # Permission in the same namespace
    permission("s3:delete")
    # Permission in another namespace
    permission("user:add")
    # Permission in another namespace with the same name as our test permission
    permission("graph:create")

    {:ok, [perms: [{"s3:create", permission}]]}
  end

  test "from_full_name", %{perms: [{full_name, permission}]} do
    retrieved = full_name
    |> Cog.Queries.Permission.from_full_name
    |> Repo.one!

    assert ^permission = retrieved
  end

end
