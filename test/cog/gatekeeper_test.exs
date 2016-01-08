defmodule GatekeeperTest do
  use Cog.ModelCase
  alias Cog.Gatekeeper

  setup do
    {:ok, [user: user("cog"),
           group: group("monkeys"),
           permission: permission("test:execute_command")]}
  end

  test "a user without a permission is not permitted", context do
    user = context[:user]
    permission = context[:permission]
    refute(Gatekeeper.user_is_permitted?(user, permission))
  end

  test "a user with a permission granted directly is permitted", context do
    user = context[:user]
    permission = context[:permission]

    :ok = Permittable.grant_to(user, permission)

    assert(Gatekeeper.user_is_permitted?(user, permission))
  end

  test "a user in a group that has a permission also has that permission", context do
    user = context[:user]
    permission = context[:permission]
    group = group("test_group")

    :ok = Permittable.grant_to(group, permission)

    refute(Gatekeeper.user_is_permitted?(user, permission))

    :ok = user |> Groupable.add_to(group)
    assert(Gatekeeper.user_is_permitted?(user, permission))
  end

  test "a user nested in a group that has a permission also has that permission", context do
    user = context[:user]
    permission = context[:permission]
    outer_group = group("outer_group")
    inner_group = group("inner_group")

    user |> Groupable.add_to(inner_group)
    inner_group |> Groupable.add_to(outer_group)
    refute(Gatekeeper.user_is_permitted?(user, permission))

    :ok = Permittable.grant_to(outer_group, permission)
    assert(Gatekeeper.user_is_permitted?(user, permission))
  end

  test "a user nested several groups in a group that has a permission also has that permission", context do
    user = context[:user]
    permission = context[:permission]

    # Create a series of groups, nested in each other.  Pick out the
    # opposite ends of the nested groups for reference later.
    groups = Enum.map(["ga", "gb", "gc", "gd"],&group(&1))
    :ok = nest_group_chain(groups)
    [outer,_,_,inner] = groups

    # Grant the permission to the outer-most group; the user (not in
    # that group) should not have the permission
    :ok = Permittable.grant_to(outer, permission)
    refute(Gatekeeper.user_is_permitted?(user, permission))

    # Add the user to the inner-most group, however, and it will have
    # the permission
    user |> Groupable.add_to(inner)
    assert(Gatekeeper.user_is_permitted?(user, permission))
  end

  test "a user has the union of permissions of all groups it is a member of", context do
    user = context[:user]

    # Create a series of groups, nested in each other
    groups = Enum.map(["ga", "gb", "gc", "gd"], &group(&1))
    :ok = nest_group_chain(groups)

    # Create a permission for each group
    permissions = Enum.map(["p:a", "p:b", "p:c", "p:d"], &permission(&1))

    # Grant each permission to its corresponding group (one permission
    # per group)
    Enum.zip(groups, permissions)
    |> Enum.map(fn({g,p}) ->
      :ok = Permittable.grant_to(g,p)
    end)

    # The user (not yet in any group) has none of the permissions
    Enum.each(permissions,
      fn(p) ->
        refute(Gatekeeper.user_is_permitted?(user, p))
      end)

    # Add the user to the inner-most group
    [_,_,_,inner_group] = groups
    user |> Groupable.add_to(inner_group)

    # Now, the user has *all* the permissions, by virtue of the group
    # membership.
    Enum.each(permissions,
      fn(p) ->
        assert(Gatekeeper.user_is_permitted?(user, p))
      end)

  end

  test "a user with a directly-granted role that has a permission also has that permission", context do
    user = context[:user]
    {role, permission} = role_with_permission("ops", "test:do_stuff")

    refute(Gatekeeper.user_is_permitted?(user, permission))
    :ok = Permittable.grant_to(user, role)

    assert(Gatekeeper.user_is_permitted?(user, permission))
  end

  test "a user in a group that has a role has the permission in that role", context do
    user = context[:user]
    {role, permission} = role_with_permission("ops", "test:do_stuff")
    group = context[:group]
    Permittable.grant_to(group, role)

    refute(Gatekeeper.user_is_permitted?(user, permission))
    user |> Groupable.add_to(group)

    assert(Gatekeeper.user_is_permitted?(user, permission))
  end

  test "a user in a group nested in a group that has a role has the permissions of that role", context do
    user = context[:user]
    {role, permission} = role_with_permission("ops", "test:do_stuff")
    group = context[:group]
    outer_group = group("outer")

    group |> Groupable.add_to(outer_group)
    Permittable.grant_to(outer_group, role)

    refute(Gatekeeper.user_is_permitted?(user, permission))
    user |> Groupable.add_to(group)

    assert(Gatekeeper.user_is_permitted?(user, permission))

  end

end
