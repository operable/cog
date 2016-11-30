defmodule Cog.V1.RoleGrantController.Test do
  use Cog.ModelCase
  use Cog.ConnCase

  setup do
    required_permission = permission("#{Cog.Util.Misc.embedded_bundle}:manage_groups")

    # This user will be used to test the normal operation of the controller
    authed_user = user("cog")
    |> with_token
    |> with_permission(required_permission)

    # This user will be used to verify that the above permission is
    # indeed required for requests
    unauthed_user = user("sadpanda") |> with_token

    group = group("robots")

    {:ok, [authed: authed_user,
           unauthed: unauthed_user,
           group: group]}
  end

  # Grant
  ########################################################################

  test "grant a single role to a group", %{authed: requestor,
                                           group: group} do
    role_permission = permission("site:deploy_test")
    role = role("admin")
    Permittable.grant_to(role, role_permission)
    assert_permission_is_granted(role, role_permission)
    refute_role_is_granted(group, role)

    conn = api_request(requestor, :post, "/v1/groups/#{group.id}/roles",
                       body: %{"roles" => %{"grant" => ["admin"]}})

    assert %{"roles" => [%{"id" => role.id,
                           "name" => role.name,
                           "permissions" => [%{"id" => role_permission.id,
                                               "name" => role_permission.name,
                                               "bundle" => "site"}]}]} == json_response(conn, 200)

    assert_role_is_granted(group, role)
  end

  test "grant multiple roles to a group at once", %{authed: requestor,
                                                    group: group} do
    # Set up roles
    role_names = ["admin", "dev", "ops"]
    roles = Enum.map(role_names, &role(&1))
    refute_role_is_granted(group, roles)

    # Grant the roles
    conn = api_request(requestor, :post, "/v1/groups/#{group.id}/roles",
                       body: %{"roles" => %{"grant" => role_names}})
    granted_roles = json_response(conn, 200)["roles"]

    # Verify the response body
    [admin, dev, ops] = roles
    assert [%{"id" => admin.id,
              "name" => admin.name,
              "permissions" => []},
            %{"id" => dev.id,
              "name" => dev.name,
              "permissions" => []},
            %{"id" => ops.id,
              "name" => ops.name,
              "permissions" => []}] == granted_roles |> sort_by("name")

    # Ensure grants are persisted in the database
    assert_role_is_granted(group, roles)
  end

  test "response from a grant includes all roles directly granted to a group", %{authed: requestor,
                                                                                 group: group} do
    # Give the thing a role from the start
    pre_existing = role("admin")
    :ok = Permittable.grant_to(group, pre_existing)

    # Grant a new role
    new_role = role("dev")
    conn = api_request(requestor, :post, "/v1/groups/#{group.id}/roles",
                       body: %{"roles" => %{"grant" => [new_role.name]}})
    granted_roles = json_response(conn, 200)["roles"]

    # You should see both roles in the response body
    assert [%{"id" => pre_existing.id,
              "name" => pre_existing.name,
              "permissions" => []},
            %{"id" => new_role.id,
              "name" => new_role.name,
              "permissions" => []}] == granted_roles |> sort_by("name")

    # Verify they're both in the database
    assert_role_is_granted(group, [pre_existing, new_role])
  end

  test "fails all grants to a group if any role does not exist", %{authed: requestor,
                                                                   group: group} do
    existing = role("admin")
    refute_role_is_granted(group, existing)

    conn = api_request(requestor, :post, "/v1/groups/#{group.id}/roles",
                       body: %{"roles" => %{"grant" => [existing.name,
                                                        "does_not_exist"]}})
    assert json_response(conn, 422) == %{"error" => "Cannot find one or more specified roles: does_not_exist"}

    refute_role_is_granted(group, existing)
  end

  test "grant works even when the group already has that role in the first place", %{authed: requestor,
                                                                                     group: group} do
    role = role("admin")
    :ok = Permittable.grant_to(group, role)

    conn = api_request(requestor, :post, "/v1/groups/#{group.id}/roles",
                       body: %{"roles" => %{"grant" => [role.name]}})

    assert %{"roles" => [%{"id" => role.id,
                           "name" => role.name,
                           "permissions" => []}]} == json_response(conn, 200)

    # Still got it!
    assert_role_is_granted(group, role)
  end

  test "unauthed users cannot grant roles to groups", %{unauthed: requestor,
                                                        group: group} do
    role = role("admin")

    conn = api_request(requestor, :post, "/v1/groups/#{group.id}/roles",
                       body: %{"roles" => %{"grant" => [role.name]}})

    assert conn.halted
    assert conn.status == 403

    refute_role_is_granted(group, role)
  end

  # Revoke
  ########################################################################

  test "revoke a single role from a group", %{authed: requestor,
                                              group: group} do
    role = role("admin")
    :ok = Permittable.grant_to(group, role)

    conn = api_request(requestor, :post, "/v1/groups/#{group.id}/roles",
                       body: %{"roles" => %{"revoke" => [role.name]}})

    assert %{"roles" => []} == json_response(conn, 200)

    refute_role_is_granted(group, role)
  end

  test "revoke multiple roles from a group at once", %{authed: requestor,
                                                       group: group} do
    # Grant multiple roles to the group
    role_names = ["admin", "dev", "ops"]
    roles = Enum.map(role_names, &role(&1))
    Enum.each(roles, &Permittable.grant_to(group, &1))

    # Revoke the roles
    conn = api_request(requestor, :post, "/v1/groups/#{group.id}/roles",
                       body: %{"roles" => %{"revoke" => role_names}})

    # Verify the response body
    assert %{"roles" => []} == json_response(conn, 200)

    # Ensure revokes are persisted in the database
    refute_role_is_granted(group, roles)
  end

  test "response from a revoke includes all roles directly granted to a group", %{authed: requestor,
                                                                                  group: group} do
    # Give the user two roles from the start
    role_names = ["admin", "dev"]
    roles = [remaining_role, to_be_revoked_role] = Enum.map(role_names, &role(&1))
    Enum.each(roles, &Permittable.grant_to(group, &1))

    # Revoke one of them
    conn = api_request(requestor, :post, "/v1/groups/#{group.id}/roles",
                       body: %{"roles" => %{"revoke" => [to_be_revoked_role.name]}})

    # only the revoked role is, um, revoked
    assert %{"roles" => [%{"id" => remaining_role.id,
                           "name" => remaining_role.name,
                           "permissions" => []}]} == json_response(conn, 200)

    assert_role_is_granted(group, remaining_role)
    refute_role_is_granted(group, to_be_revoked_role)
  end

  test "fails all revokes against a group if any role does not exist", %{authed: requestor,
                                                                         group: group} do
    existing = role("admin")
    :ok = Permittable.grant_to(group, existing)

    conn = api_request(requestor, :post, "/v1/groups/#{group.id}/roles",
                       body: %{"roles" => %{"revoke" => [existing.name,
                                                         "does_not_exist"]}})
    assert json_response(conn, 422) == %{"error" => "Cannot find one or more specified roles: does_not_exist"}

    # Still got it
    assert_role_is_granted(group, existing)
  end

  test "revoke works even when the group didn't have that role in the first place", %{authed: requestor,
                                                                                      group: group} do
    role = role("admin")
    refute_role_is_granted(group, role)

    conn = api_request(requestor, :post, "/v1/groups/#{group.id}/roles",
                       body: %{"roles" => %{"revoke" => [role.name]}})

    assert %{"roles" => []} == json_response(conn, 200)
    refute_role_is_granted(group, role)
  end

  test "unauthed users cannot revoke roles from groups", %{unauthed: requestor,
                                                           group: group} do
    role = role("admin")
    :ok = Permittable.grant_to(group, role)

    conn = api_request(requestor, :post, "/v1/groups/#{group.id}/roles",
                       body: %{"roles" => %{"revoke" => [role.name]}})

    assert conn.halted
    assert conn.status == 403

    # Yup, still got it
    assert_role_is_granted(group, role)
  end

  test "cannot revoke the #{Cog.Util.Misc.admin_role} role from the #{Cog.Util.Misc.admin_group} group", %{authed: requestor} do
    # This is how the role and group get there in the first place
    Cog.Bootstrap.bootstrap

    admin_role = %Cog.Models.Role{} = Cog.Repository.Roles.by_name(Cog.Util.Misc.admin_role)
    {:ok, admin_group}              = Cog.Repository.Groups.by_name(Cog.Util.Misc.admin_group)

    conn = api_request(requestor, :post, "/v1/groups/#{admin_group.id}/roles",
                       body: %{"roles" => %{"revoke" => [admin_role.name]}})

    error_msg = "Cannot remove '#{unquote(Cog.Util.Misc.admin_role)}' role from '#{unquote(Cog.Util.Misc.admin_group)}' group"
    assert %{"error" => ^error_msg} = json_response(conn, 422)

    assert_role_is_granted(admin_group, admin_role)
  end

end
