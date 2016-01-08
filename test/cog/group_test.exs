defmodule GroupTest do
  use Cog.ModelCase

  setup do
    {:ok, [user: user("cog"),
           role: role("create"),
           group: group("test_group"),
           permission: permission("test:creation")]}
  end

  test "users can be added as members of a group", %{user: user, group: group} do
    user |> Groupable.add_to(group)
    assert_group_member_was_added(group, user)
  end

  test "adding a user to a group is idempotent", %{user: user, group: group} do
    :ok = Groupable.add_to(user, group)
    assert(:ok = Groupable.add_to(user, group))
  end

  test "permissions may be granted directly to groups", %{group: group, permission: permission} do
    :ok = Permittable.grant_to(group, permission)
    assert_permission_is_granted(group, permission)
  end

  test "granting a permission to a group is idempotent", %{group: group, permission: permission} do
    :ok = Permittable.grant_to(group, permission)
    assert(:ok = Permittable.grant_to(group, permission))
  end

  test "adding a group as a member of itself (i.e., creating a degenerate cycle) is not allowed", %{group: group} do
    assert({:error, :forbidden_group_cycle} = Groupable.add_to(group, group))
  end

  test "adding a group to a group cannot create a cycle" do
    outer_group = group("outer_group")
    middle_group = group("middle_group")
    inner_group = group("inner_group")

    nest_group_chain([outer_group,
                      middle_group,
                      inner_group])

    assert({:error, :forbidden_group_cycle} = Groupable.add_to(outer_group, inner_group))
  end

  test "a group may be added to a group", %{group: group} do
    inner_group = group("inner")
    assert(:ok = Groupable.add_to(inner_group, group))
    assert_group_member_was_added(group, inner_group)
  end

  test "adding a group to a group is idempotent", %{group: group} do
    inner_group = group("inner")
    :ok = Groupable.add_to(inner_group, group)
    assert(:ok = Groupable.add_to(inner_group, group))
  end

  test "roles may be granted directly to a group", %{group: group, role: role} do
    :ok = Permittable.grant_to(group, role)
    assert_role_was_granted(group, role)
  end

  test "granting a role to a group is idempotent", %{group: group, role: role} do
    :ok = Permittable.grant_to(group, role)
    assert(:ok = Permittable.grant_to(group, role))
  end

end
