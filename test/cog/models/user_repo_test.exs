defmodule Cog.Models.UserRepoTest do
  use ExUnit.Case

  use Cog.ModelCase, async: false
  alias Cog.Models.User

  test "permission views are mutually consistent" do
    user = user("cog")
    group = group("test-group")
    role = role("test-role")
    permission = permission("site:test-permission")

    Permittable.grant_to(role, permission)
    Permittable.grant_to(group, role)
    Groupable.add_to(user, group)

    assert User.has_permission(user, permission)
    assert "site:test-permission" in User.all_permissions(user)
  end
end
