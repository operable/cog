defmodule DatabaseAssertions do
  alias Cog.Repo
  import ExUnit.Assertions

  alias Cog.Models.Permission
  alias Cog.Models.Role

  @doc """
  Asserts that each given permission is directly associated to the
  grantee in question.

  Does NOT test permissions associated by recursive group membership.

  Example:

      assert_permission_is_granted(user, permission)
      assert_permission_is_granted(user, [perm1, perm2])

  """
  def assert_permission_is_granted(grantee, %Permission{}=permission),
    do: assert_permission_is_granted(grantee, [permission])
  def assert_permission_is_granted(grantee, permissions) when is_list (permissions) do
    loaded = Repo.preload(grantee, :permissions)
    Enum.each(permissions,
      fn(p) -> assert p in loaded.permissions end)
  end

  @doc """
  Asserts that each given permission is NOT directly associated to the
  grantee in question.

  Does NOT test permissions associated by recursive group membership.

  Example:

      refute_permission_is_granted(user, permission)
      refute_permission_is_granted(user, [perm1, perm2])

  """
  def refute_permission_is_granted(grantee, %Permission{}=permission),
    do: refute_permission_is_granted(grantee, [permission])
  def refute_permission_is_granted(grantee, permissions) when is_list (permissions) do
    loaded = Repo.preload(grantee, :permissions)
    Enum.each(permissions,
      fn(p) -> refute p in loaded.permissions end)
  end


  def assert_role_is_granted(grantee, %Role{}=role),
    do: assert_role_is_granted(grantee, [role])
  def assert_role_is_granted(grantee, roles) when is_list(roles) do
    loaded = Repo.preload(grantee, :roles)
    Enum.each(roles,
      fn(p) -> assert p in loaded.roles end)
  end

  def refute_role_is_granted(grantee, %Role{}=role),
    do: refute_role_is_granted(grantee, [role])
  def refute_role_is_granted(grantee, roles) when is_list(roles) do
    loaded = Repo.preload(grantee, :roles)
    Enum.each(roles,
      fn(p) -> refute p in loaded.roles end)
  end

  def assert_rule_is_persisted(id, rule_text) do
    {:ok, expr, _} = Piper.Permissions.Parser.parse(rule_text, json: true)
    rule = Repo.get_by!(Cog.Models.Rule, parse_tree: expr)
    assert rule.id == id
  end

  def refute_rule_is_persisted(rule_text) do
    {:ok, expr, _} = Piper.Permissions.Parser.parse(rule_text, json: true)
    refute Repo.get_by(Cog.Models.Rule, parse_tree: expr)
  end

  def assert_role_was_granted(grantee, role) do
    loaded = Repo.preload(grantee, :roles)
    assert role in loaded.roles
  end

  def assert_group_member_was_added(group, %Cog.Models.User{}=member) do
    loaded = Repo.preload(group, :direct_user_members)
    assert member in loaded.direct_user_members
  end
  def assert_group_member_was_added(group, %Cog.Models.Group{}=member) do
    loaded = Repo.preload(group, :direct_group_members)
    assert member in loaded.direct_group_members
  end
end
