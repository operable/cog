defmodule Cog.V1.PermissionGrantController.Test do
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
                            :role -> permission("#{Cog.embedded_bundle}:manage_roles")
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
               :role -> role("admin")
               :group -> group("engineering")
             end

    # Once we have a target, we can create an API request path that is
    # appropriate for the kind of entity we're targeting. Every
    # request will use this path.
    path = case context[:base] do
             :user  -> "/v1/users/#{target.id}/permissions"
             :role  -> "/v1/roles/#{target.id}/permissions"
             :group -> "/v1/groups/#{target.id}/permissions"
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
  [:user, :role, :group] |> Enum.each(
    fn(base) ->

      # Grant
      ########################################################################

      @tag base: base
      test "grant a single permission to a #{base}", %{authed: requestor,
                                                       target: target,
                                                       path: path} do
        permission = permission("site:do_stuff")
        refute_permission_is_granted(target, permission)

        conn = api_request(requestor, :post, path,
                           body: %{"permissions" => %{"grant" => ["site:do_stuff"]}})

        %{id: id, name: name} = permission
        assert %{"permissions" => [%{"id" => ^id, "name" => ^name}]} = json_response(conn, 200)

        assert_permission_is_granted(target, permission)
      end

      @tag base: base
      test "grant multiple permissions to a #{base} at once", %{authed: requestor,
                                                                target: target,
                                                                path: path} do
        # Set up permissions
        permission_names = ["site:first", "site:second", "site:third"]
        permissions = Enum.map(permission_names, &permission(&1))
        refute_permission_is_granted(target, permissions)

        # Grant the permissions
        conn = api_request(requestor, :post, path,
                           body: %{"permissions" => %{"grant" => permission_names}})
        granted_permissions = json_response(conn, 200)["permissions"] |> sort_by("name")

        # Verify the response body
        [first, second, third] = permissions
        assert first.id == Enum.at(granted_permissions, 0)["id"]
        assert first.name == Enum.at(granted_permissions, 0)["name"]
        assert second.id == Enum.at(granted_permissions, 1)["id"]
        assert second.name == Enum.at(granted_permissions, 1)["name"]
        assert third.id == Enum.at(granted_permissions, 2)["id"]
        assert third.name == Enum.at(granted_permissions, 2)["name"]

        # Ensure grants are persisted in the database
        assert_permission_is_granted(target, permissions)
      end

      @tag base: base
      test "response from a grant includes all permissions directly granted to a #{base}", %{authed: requestor,
                                                                                             target: target,
                                                                                             path: path} do
        # Give the thing a permission from the start
        pre_existing = permission("site:first")
        :ok = Permittable.grant_to(target, pre_existing)

        # Grant a new permission
        new_permission = permission("site:second")
        conn = api_request(requestor, :post, path,
                           body: %{"permissions" => %{"grant" => ["site:second"]}})
        granted_permissions = json_response(conn, 200)["permissions"] |> sort_by("name")

        # You should see both permissions in the response body
        assert pre_existing.id == Enum.at(granted_permissions, 0)["id"]
        assert pre_existing.name == Enum.at(granted_permissions, 0)["name"]
        assert new_permission.id == Enum.at(granted_permissions, 1)["id"]
        assert new_permission.name == Enum.at(granted_permissions, 1)["name"]

        # Verify they're both in the database
        assert_permission_is_granted(target, pre_existing)
        assert_permission_is_granted(target, new_permission)
      end

      @tag base: base
      test "fails all grants to a #{base} if any permission does not exist", %{authed: requestor,
                                                                               target: target,
                                                                               path: path} do
        existing = permission("site:first")
        refute_permission_is_granted(target, existing)

        conn = api_request(requestor, :post, path,
                           body: %{"permissions" => %{"grant" => ["site:first",
                                                                  "site:does_not_exist"]}})
        assert json_response(conn, 422) == %{"error" => %{"not_found" => %{"permissions" => ["site:does_not_exist"]}}}

        refute_permission_is_granted(target, existing)
      end

      @tag base: base
      test "grant works even when the #{base} already has that permission in the first place", %{authed: requestor,
                                                                                                 target: target,
                                                                                                 path: path} do
        permission = permission("site:do_stuff")
        :ok = Permittable.grant_to(target, permission)

        conn = api_request(requestor, :post, path,
                           body: %{"permissions" => %{"grant" => ["site:do_stuff"]}})

        %{id: id, name: name} = permission
        assert %{"permissions" => [%{"id" => ^id, "name" => ^name}]} = json_response(conn, 200)

        # Still got it!
        assert_permission_is_granted(target, permission)
      end

      @tag base: base
      test "unauthed users cannot grant permissions to #{base}s", %{unauthed: requestor,
                                                                    target: target,
                                                                    path: path} do
        permission = permission("site:do_stuff")

        conn = api_request(requestor, :post, path,
                           body: %{"permissions" => %{"grant" => ["site:do_stuff"]}})

        assert conn.halted
        assert conn.status == 403

        refute_permission_is_granted(target, permission)

      end

      # Revoke
      ########################################################################

      @tag base: base
      test "revoke a single permission from a #{base}", %{authed: requestor,
                                                          target: target,
                                                          path: path} do
        permission = permission("site:do_stuff")
        :ok = Permittable.grant_to(target, permission)

        conn = api_request(requestor, :post, path,
                           body: %{"permissions" => %{"revoke" => ["site:do_stuff"]}})

        assert %{"permissions" => []} == json_response(conn, 200)

        refute_permission_is_granted(target, permission)
      end

      @tag base: base
      test "revoke multiple permissions from a #{base} at once", %{authed: requestor,
                                                                   target: target,
                                                                   path: path} do
        # Setup a user and grant multiple permissions to it
        permission_names = ["site:first", "site:second", "site:third"]
        permissions = Enum.map(permission_names, &permission(&1))
        Enum.map(permissions, &Permittable.grant_to(target, &1))

        # Revoke the permissions
        conn = api_request(requestor, :post, path,
                           body: %{"permissions" => %{"revoke" => permission_names}})

        # Verify the response body
        assert %{"permissions" => []} == json_response(conn, 200)

        # Ensure revokes are persisted in the database
        refute_permission_is_granted(target, permissions)
      end

      @tag base: base
      test "response from a revoke includes all permissions directly granted to a #{base}", %{authed: requestor,
                                                                                              target: target,
                                                                                              path: path} do
        # Give the user two permissions from the start
        permission_names = ["site:first", "site:second"]
        permissions = [remaining_permission, to_be_revoked_permission] = Enum.map(permission_names, &permission(&1))
        Enum.map(permissions, &Permittable.grant_to(target, &1))

        # Revoke one of them
        conn = api_request(requestor, :post, path,
                           body: %{"permissions" => %{"revoke" => ["site:second"]}})

        %{id: id, name: name} = remaining_permission

        # only the revoked permission is, um, revoked
        assert %{"permissions" => [%{"id" => ^id, "name" => ^name}]} = json_response(conn, 200)

        assert_permission_is_granted(target, remaining_permission)
        refute_permission_is_granted(target, to_be_revoked_permission)
      end

      @tag base: base
      test "fails all revokes against a #{base} if any permission does not exist", %{authed: requestor,
                                                                                     target: target,
                                                                                     path: path} do
        existing = permission("site:first")
        :ok = Permittable.grant_to(target, existing)

        conn = api_request(requestor, :post, path,
                           body: %{"permissions" => %{"revoke" => ["site:first",
                                                                   "site:does_not_exist"]}})
        assert json_response(conn, 422) == %{"error" => %{"not_found" => %{"permissions" => ["site:does_not_exist"]}}}

        # Still got it
        assert_permission_is_granted(target, existing)
      end

      @tag base: base
      test "revoke works even when the #{base} didn't have that permission in the first place", %{authed: requestor,
                                                                                                  target: target,
                                                                                                  path: path} do
        permission = permission("site:do_stuff")
        refute_permission_is_granted(target, permission)

        conn = api_request(requestor, :post, path,
                           body: %{"permissions" => %{"revoke" => ["site:do_stuff"]}})

        assert %{"permissions" => []} == json_response(conn, 200)
        refute_permission_is_granted(target, permission)
      end

      @tag base: base
      test "unauthed users cannot revoke permissions from #{base}s", %{unauthed: requestor,
                                                                       target: target,
                                                                       path: path} do
        permission = permission("site:do_stuff")
        :ok = Permittable.grant_to(target, permission)

        conn = api_request(requestor, :post, path,
                           body: %{"permissions" => %{"revoke" => ["site:do_stuff"]}})

        assert conn.halted
        assert conn.status == 403

        # Yup, still got it
        assert_permission_is_granted(target, permission)
      end

    end #fn
  ) # Enum.each

end
