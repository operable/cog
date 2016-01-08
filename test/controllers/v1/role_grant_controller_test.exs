defmodule Cog.V1.RoleGrantController.Test do
  use Cog.ModelCase
  use Cog.ConnCase

  # All the permission granting/revoking API endpoints share similar
  # structure, and are all implemented by the same code. As such, the
  # tests for granting permissions to users and granting them to roles
  # or groups are all the same, so we'll just parameterize all the
  # tests as appropriate.
  #
  # As currently structured, each test should have a `:base` tag,
  # which feeds into this setup function in order to establish the
  # correct test structures.
  #
  # Example:
  #
  #     @tag base: :user
  #     test "does something with users", context do
  #       assert something_very_interesting_indeed()
  #     end
  #
  setup context do
    # Depending on which endpoint we're testing, we'll need to change
    # the permission that the user making the API requests needs to
    # have in order to be authorized to make the request.
    required_permission = case context[:base] do
                            :user -> permission("#{Cog.embedded_bundle}:manage_users")
                            :group -> permission("#{Cog.embedded_bundle}:manage_groups")
                          end

    # This user will be used to test the normal operation of the controller
    authed_user = user("cog")
    |> with_token
    |> with_permission(required_permission)

    # This user will be used to verify that the above permission is
    # indeed required for requests
    unauthed_user = user("sadpanda") |> with_token

    # The API requests are all focused around granting / revoking
    # permissions from a specific user, role, or group. In these
    # tests, we refer to this entity as the "target"
    target = case context[:base] do
               :user -> user("hal")
               :group -> group("robots")
             end

    # Once we have a target, we can create an API request path that is
    # appropriate for the kind of entity we're targeting. Every
    # request will use this path.
    path = case context[:base] do
             :user  -> "/v1/users/#{target.id}/roles"
             :group -> "/v1/groups/#{target.id}/roles"
           end

    {:ok, [authed: authed_user,
           unauthed: unauthed_user,
           target: target,
           path: path]}
  end

  # Scripting to the rescue!
  #
  # For each kind of entity we want to test, we'll generate a whole
  # series of tests focused around testing the manipulation of
  # permissions on that kind of entity.
  [:user, :group] |> Enum.each(
    fn(base) ->

      # Grant
      ########################################################################

      @tag base: base
      test "grant a single role to a #{base}", %{authed: requestor,
                                                 target: target,
                                                 path: path} do
        role = role("admin")
        refute_role_is_granted(target, role)

        conn = api_request(requestor, :post, path,
                           body: %{"roles" => %{"grant" => ["admin"]}})

        assert %{"roles" => [%{"id" => role.id,
                               "name" => role.name}]} == json_response(conn, 200)

        assert_role_is_granted(target, role)
      end

      @tag base: base
      test "grant multiple roles to a #{base} at once", %{authed: requestor,
                                                          target: target,
                                                          path: path} do
        # Set up roles
        role_names = ["admin", "dev", "ops"]
        roles = Enum.map(role_names, &role(&1))
        refute_role_is_granted(target, roles)

        # Grant the roles
        conn = api_request(requestor, :post, path,
                           body: %{"roles" => %{"grant" => role_names}})
        granted_roles = json_response(conn, 200)["roles"]

        # Verify the response body
        [admin, dev, ops] = roles
        assert [%{"id" => admin.id,
                  "name" => admin.name},
                %{"id" => dev.id,
                  "name" => dev.name},
                %{"id" => ops.id,
                  "name" => ops.name}] == granted_roles |> sort_by("name")

        # Ensure grants are persisted in the database
        assert_role_is_granted(target, roles)
      end

      @tag base: base
      test "response from a grant includes all roles directly granted to a #{base}", %{authed: requestor,
                                                                                       target: target,
                                                                                       path: path} do
        # Give the thing a role from the start
        pre_existing = role("admin")
        :ok = Permittable.grant_to(target, pre_existing)

        # Grant a new role
        new_role = role("dev")
        conn = api_request(requestor, :post, path,
                           body: %{"roles" => %{"grant" => [new_role.name]}})
        granted_roles = json_response(conn, 200)["roles"]

        # You should see both roles in the response body
        assert [%{"id" => pre_existing.id,
                  "name" => pre_existing.name},
                %{"id" => new_role.id,
                  "name" => new_role.name}] == granted_roles |> sort_by("name")

        # Verify they're both in the database
        assert_role_is_granted(target, [pre_existing, new_role])
      end

      @tag base: base
      test "fails all grants to a #{base} if any role does not exist", %{authed: requestor,
                                                                         target: target,
                                                                         path: path} do
        existing = role("admin")
        refute_role_is_granted(target, existing)

        conn = api_request(requestor, :post, path,
                           body: %{"roles" => %{"grant" => [existing.name,
                                                            "does_not_exist"]}})
        assert json_response(conn, 422) == %{"error" => %{"not_found" => %{"roles" => ["does_not_exist"]}}}

        refute_role_is_granted(target, existing)
      end

      @tag base: base
      test "grant works even when the #{base} already has that role in the first place", %{authed: requestor,
                                                                                           target: target,
                                                                                           path: path} do
        role = role("admin")
        :ok = Permittable.grant_to(target, role)

        conn = api_request(requestor, :post, path,
                           body: %{"roles" => %{"grant" => [role.name]}})

        assert %{"roles" => [%{"id" => role.id,
                               "name" => role.name}]} == json_response(conn, 200)

        # Still got it!
        assert_role_is_granted(target, role)
      end

      @tag base: base
      test "unauthed users cannot grant roles to #{base}s", %{unauthed: requestor,
                                                              target: target,
                                                              path: path} do
        role = role("admin")

        conn = api_request(requestor, :post, path,
                           body: %{"roles" => %{"grant" => [role.name]}})

        assert conn.halted
        assert conn.status == 403

        refute_role_is_granted(target, role)
      end

      # Revoke
      ########################################################################

      @tag base: base
      test "revoke a single role from a #{base}", %{authed: requestor,
                                                    target: target,
                                                    path: path} do
        role = role("admin")
        :ok = Permittable.grant_to(target, role)

        conn = api_request(requestor, :post, path,
                           body: %{"roles" => %{"revoke" => [role.name]}})

        assert %{"roles" => []} == json_response(conn, 200)

        refute_role_is_granted(target, role)
      end

      @tag base: base
      test "revoke multiple roles from a #{base} at once", %{authed: requestor,
                                                             target: target,
                                                             path: path} do
        # Grant multiple roles to the target
        role_names = ["admin", "dev", "ops"]
        roles = Enum.map(role_names, &role(&1))
        Enum.each(roles, &Permittable.grant_to(target, &1))

        # Revoke the roles
        conn = api_request(requestor, :post, path,
                           body: %{"roles" => %{"revoke" => role_names}})

        # Verify the response body
        assert %{"roles" => []} == json_response(conn, 200)

        # Ensure revokes are persisted in the database
        refute_role_is_granted(target, roles)
      end

      @tag base: base
      test "response from a revoke includes all roles directly granted to a #{base}", %{authed: requestor,
                                                                                        target: target,
                                                                                        path: path} do
        # Give the user two roles from the start
        role_names = ["admin", "dev"]
        roles = [remaining_role, to_be_revoked_role] = Enum.map(role_names, &role(&1))
        Enum.each(roles, &Permittable.grant_to(target, &1))

        # Revoke one of them
        conn = api_request(requestor, :post, path,
                           body: %{"roles" => %{"revoke" => [to_be_revoked_role.name]}})

        # only the revoked role is, um, revoked
        assert %{"roles" => [%{"id" => remaining_role.id,
                               "name" => remaining_role.name}]} == json_response(conn, 200)

        assert_role_is_granted(target, remaining_role)
        refute_role_is_granted(target, to_be_revoked_role)
      end

      @tag base: base
      test "fails all revokes against a #{base} if any role does not exist", %{authed: requestor,
                                                                               target: target,
                                                                               path: path} do
        existing = role("admin")
        :ok = Permittable.grant_to(target, existing)

        conn = api_request(requestor, :post, path,
                           body: %{"roles" => %{"revoke" => [existing.name,
                                                             "does_not_exist"]}})
        assert json_response(conn, 422) == %{"error" => %{"not_found" => %{"roles" => ["does_not_exist"]}}}

        # Still got it
        assert_role_is_granted(target, existing)
      end

      @tag base: base
      test "revoke works even when the #{base} didn't have that role in the first place", %{authed: requestor,
                                                                                            target: target,
                                                                                            path: path} do
        role = role("admin")
        refute_role_is_granted(target, role)

        conn = api_request(requestor, :post, path,
                           body: %{"roles" => %{"revoke" => [role.name]}})

        assert %{"roles" => []} == json_response(conn, 200)
        refute_role_is_granted(target, role)
      end

      @tag base: base
      test "unauthed users cannot revoke roles from #{base}s", %{unauthed: requestor,
                                                                 target: target,
                                                                 path: path} do
        role = role("admin")
        :ok = Permittable.grant_to(target, role)

        conn = api_request(requestor, :post, path,
                           body: %{"roles" => %{"revoke" => [role.name]}})

        assert conn.halted
        assert conn.status == 403

        # Yup, still got it
        assert_role_is_granted(target, role)
      end

    end #fn
  ) # Enum.each

end
