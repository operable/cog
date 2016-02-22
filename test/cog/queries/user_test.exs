defmodule Cog.Queries.User.Test do
  use Cog.ModelCase

  alias Cog.Models.User

  setup do
    # add a few extra users we won't grant anything to, just to ensure
    # we're being selective
    user("somebody")
    user("somebody-else")
    user("that-puppy-over-there")

    :ok
  end

  test "user with direct permission is found" do
    user = user("test")
    permission = permission("site:test")
    Permittable.grant_to(user, permission)

    assert_has_permission(user, permission)
  end

  test "user with granted role permission is found" do
    user = user("test")
    role = role("test_role")
    permission = permission("site:test")
    Permittable.grant_to(role, permission)
    Permittable.grant_to(user, role)

    assert_has_permission(user, permission)
  end

  test "user in group with directly-granted permission is found" do
    user = user("test")
    group = group("group")
    permission = permission("site:test")
    Permittable.grant_to(group, permission)
    Groupable.add_to(user, group)

    assert_has_permission(user, permission)
  end

  test "user in group with directly-granted role permission is found" do
    user = user("test")
    role = role("role")
    group = group("group")
    permission = permission("site:test")
    Permittable.grant_to(role, permission)
    Permittable.grant_to(group, role)
    Groupable.add_to(user, group)

    assert_has_permission(user, permission)
  end

  test "user in group in a group with a directly-granted permission is found" do
    user = user("test")
    inner = group("inner")
    outer = group("outer")
    permission = permission("site:test")
    Permittable.grant_to(outer, permission)
    Groupable.add_to(user, inner)
    Groupable.add_to(inner, outer)

    assert_has_permission(user, permission)
  end

  test "user in group in a group with a role-granted permission is found" do
    user = user("test")
    role = role("role")
    inner = group("inner")
    outer = group("outer")
    permission = permission("site:test")
    Permittable.grant_to(role, permission)
    Permittable.grant_to(outer, role)
    Groupable.add_to(user, inner)
    Groupable.add_to(inner, outer)

    assert_has_permission(user, permission)
  end

  test "ensure that multiple users can be found (i.e., all the preceding tests in one)" do
    permission = permission("site:test")
    role = role("role")
    Permittable.grant_to(role, permission)

    # Setup groups
    gp = group("group-with-permission")
    Permittable.grant_to(gp, permission)
    gr = group("group-with-role")
    Permittable.grant_to(gr, role)
    ggp = group("group-in-group-with-permission")
    Groupable.add_to(ggp, gp)
    ggr = group("group-in-group-with-role")
    Groupable.add_to(ggr, gr)

    # Setup users
    up = user("user-with-permission")
    Permittable.grant_to(up, permission)
    ur = user("user-with-role")
    Permittable.grant_to(ur, role)
    ugp = user("user-in-group-with-permission")
    Groupable.add_to(ugp, gp)
    ugr = user("user-in-group-with-role")
    Groupable.add_to(ugr, gr)
    uggp = user("user-in-group-in-group-with-permission")
    Groupable.add_to(uggp, ggp)
    uggr = user("user-in-group-in-group-with-role")
    Groupable.add_to(uggr, ggr)

    expected_usernames = [up, ur, ugp, ugr, uggp, uggr] |> ordered_usernames
    actual_usernames = Cog.Queries.User.with_permission(permission) |> Repo.all |> ordered_usernames

    assert expected_usernames == actual_usernames
  end

  # Ensure that the `Cog.Queries.User.with_permission/2` query returns
  # the appropriate information, and that it agrees with
  # `User.has_permission/2` which is its inverse.
  defp assert_has_permission(user, permission) do
    assert User.has_permission(user, permission)
    assert [user.username] == Cog.Queries.User.with_permission(permission) |> Repo.all |> ordered_usernames
  end

  defp ordered_usernames(users),
    do: users |> Enum.map(&(&1.username)) |> Enum.sort
end
