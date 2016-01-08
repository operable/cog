defmodule Cog.V1.RoleController.Test do
  use Cog.ModelCase
  use Cog.ConnCase

  alias Cog.Models.Role

  @bad_uuid "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"

  setup do
    # Requests handled by the role controller require this permission
    required_permission = permission("#{Cog.embedded_bundle}:manage_roles")

    # This user will be used to test the normal operation of the controller
    authed_user = user("cog")
    |> with_token
    |> with_permission(required_permission)

    # This user will be used to verify that the above permission is
    # indeed required for requests
    unauthed_user = user("sadpanda") |> with_token

    {:ok, [authed: authed_user,
           unauthed: unauthed_user]}
  end

  test "index returns empty list when no roles exist", %{authed: user} do
    conn = api_request(user, :get, "/v1/roles")
    assert [] = json_response(conn, 200)["roles"]
  end

  test "index returns single role when only one exists", %{authed: user} do
    role = role("monkey")
    conn = api_request(user, :get, "/v1/roles")
    assert %{"roles" => [%{"id" => role.id,
                           "name" => "monkey"}]} == json_response(conn, 200)
  end

  test "index returns multiple roles when multiple exist", %{authed: user} do
    first = role("first")
    second = role("second")

    conn = api_request(user, :get, "/v1/roles")
    assert [%{"id" => first.id,
              "name" => "first"},
            %{"id" => second.id,
              "name" => "second"}] == json_response(conn, 200)["roles"] |> sort_by("name")
  end

  test "create works on the happy path", %{authed: user} do
    conn = api_request(user, :post, "/v1/roles",
                       body: %{"role" => %{"name" => "admin"}})
    id = json_response(conn, 201)["role"]["id"]

    expected_location = "/v1/roles/#{id}"
    assert ^expected_location = redirected_to(conn, 201)
  end

  test "create fails with missing name", %{authed: user} do
    conn = api_request(user, :post, "/v1/roles",
                       body: %{"role" => %{"stuff" => "things"}})
    body = json_response(conn, 422)

    assert %{"name" => ["can't be blank"]} = body["errors"]
  end

  test "create fails when attempting to duplicate a role", %{authed: user} do
    existing = role("admin")
    conn = api_request(user, :post, "/v1/roles",
                       body: %{"role" => %{"name" => existing.name}})
    body = json_response(conn, 422)

    assert %{"name" => ["has already been taken"]} = body["errors"]
  end

  test "show works on the happy path", %{authed: user} do
    role = role("admin")
    conn = api_request(user, :get, "/v1/roles/#{role.id}")
    assert %{"role" => %{"id" => role.id,
                         "name" => "admin"}} == json_response(conn, 200)
  end

  test "show fails when the role doesn't exist", %{authed: user} do
    error = catch_error(api_request(user, :get, "/v1/roles/#{@bad_uuid}"))
    assert %Ecto.NoResultsError{} = error
  end

  test "show fails when supplying a non-uuid path parameter", %{authed: user} do
    error = catch_error(api_request(user, :get, "/v1/roles/not-a-uuid"))
    assert %Ecto.CastError{} = error
  end

  test "update can change a role's name", %{authed: user} do
    role = role("admin")
    conn = api_request(user, :put, "/v1/roles/#{role.id}",
                       body: %{"role" => %{"name" => "other"}})
    assert %{"role" => %{"id" => role.id,
                         "name" => "other"}} == json_response(conn, 200)

  end

  test "update fails when the role doesn't exist", %{authed: user} do
    error = catch_error(api_request(user, :put, "/v1/roles/#{@bad_uuid}",
                                    body: %{"role" => %{"name" => "something_new_and_different"}}))
    assert %Ecto.NoResultsError{} = error
  end

  test "update fails with invalid data", %{authed: user} do
    %Role{id: id} = role("admin")
    conn = api_request(user, :put, "/v1/roles/#{id}",
                       body: %{"role" => %{"name" => 666}})
    body = json_response(conn, 422)
    assert %{"name" => ["is invalid"]} = body["errors"]
  end

  test "update changing the name to existing name fails", %{authed: user} do
    original = role("admin")
    new = role("testing")
    conn = api_request(user, :put, "/v1/roles/#{new.id}",
                       body: %{"role" => %{"name" => original.name}})
    body = json_response(conn, 422)
    assert %{"name" => ["has already been taken"]} = body["errors"]
  end

  test "delete works in the happy path", %{authed: user} do
    role = role("admin")
    conn = api_request(user, :delete, "/v1/roles/#{role.id}")
    assert "" == response(conn, 204)
    refute Repo.get_by(Role, id: role.id)
  end

  test "delete fails when the role doesn't exist", %{authed: user} do
    error = catch_error(api_request(user, :delete, "/v1/roles/#{@bad_uuid}"))
    assert %Ecto.NoResultsError{} = error
  end

  test "cannot list roles without permission", %{unauthed: user} do
    conn = api_request(user, :get, "/v1/roles")
    assert conn.halted
    assert conn.status == 403
  end

  test "cannot create a role without permission", %{unauthed: user} do
    conn = api_request(user, :post, "/v1/roles",
                       body: %{"role" => %{"name" => "admin"}})
    assert conn.halted
    assert conn.status == 403
  end

  test "cannot retrieve a role without permission", %{unauthed: user} do
    role = role("admin")
    conn = api_request(user, :get, "/v1/roles/#{role.id}")
    assert conn.halted
    assert conn.status == 403
  end

  test "cannot edit a role without permission", %{unauthed: user} do
    role = role("admin")
    conn = api_request(user, :put, "/v1/roles/#{role.id}",
                       body: %{"role" => %{"name" => "administrator"}})
    assert conn.halted
    assert conn.status == 403
  end

  test "cannot delete a role without permission", %{unauthed: user} do
    role = role("admin")
    conn = api_request(user, :delete, "/v1/roles/#{role.id}")
    assert conn.halted
    assert conn.status == 403
  end

end
