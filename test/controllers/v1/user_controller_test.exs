defmodule Cog.V1.UserControllerTest do
  use Cog.ModelCase
  use Cog.ConnCase

  alias Cog.Models.User

  @valid_attrs %{username: "tester",
                 password: "password",
                 first_name: "Joe",
                 last_name: "Mike",
                 email_address: "robert@cog.test"}
  @invalid_attrs %{first_name: -1,
                   last_name: "Huh",
                   email_address: "Nah"}

  @bad_uuid "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"

  setup do
    # Requests handled by the role controller require this permission
    required_permission = permission("#{Cog.embedded_bundle}:manage_users")

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

  test "lists all entries on index", %{authed: requestor, unauthed: other} do
    conn = api_request(requestor, :get, "/v1/users")
    users_json = json_response(conn, 200)["users"]
    assert [%{"id" => requestor.id,
              "first_name" => "Cog",
              "last_name" => "McCog",
              "email_address" => "cog@operable.io",
              "username" => "cog"},
            %{"id" => other.id,
              "first_name" => "Sadpanda",
              "last_name" => "McSadpanda",
              "email_address" => "sadpanda@operable.io",
              "username" => "sadpanda"}] == users_json |> sort_by("username")
  end

  test "shows chosen resource", %{authed: requestor} do
    user = user("tester")
    conn = api_request(requestor, :get, "/v1/users/#{user.id}")
    assert %{"user" => %{"id" => user.id,
                         "username" => "tester",
                         "first_name" => "Tester",
                         "last_name" => "McTester",
                         "email_address" => "tester@operable.io"}} == json_response(conn, 200)
  end

  test "does not show resource and instead throw error when id is nonexistent", %{authed: requestor} do
    error = catch_error(api_request(requestor, :get, "/v1/users/#{@bad_uuid}"))
    assert %Ecto.NoResultsError{} = error
  end

  test "creates and renders resource when data is valid", %{authed: requestor} do
    conn = api_request(requestor, :post, "/v1/users", body: %{"user" => @valid_attrs})
    id = json_response(conn, 201)["user"]["id"]
    assert Repo.get_by(User, id: id)
  end

  test "does not create resource and renders errors when data is invalid", %{authed: requestor} do
    conn = api_request(requestor, :post, "/v1/users", body: %{"user" => @invalid_attrs})
    assert json_response(conn, 422)["errors"] != %{}
  end

  test "updates and renders chosen resource when data is valid", %{authed: requestor} do
    user = user("tester")
    conn = api_request(requestor, :put, "/v1/users/#{user.id}",
                       body: %{"user" => @valid_attrs})
    assert json_response(conn, 200)["user"] == %{"id" => user.id,
                                                 "username" => @valid_attrs.username,
                                                 "first_name" => @valid_attrs.first_name,
                                                 "email_address" => @valid_attrs.email_address,
                                                 "last_name" => @valid_attrs.last_name}
  end

  test "does not update chosen resource and renders errors when data is invalid", %{authed: requestor} do
    user = user("test")
    conn = api_request(requestor, :put, "/v1/users/#{user.id}",
                       body: %{"user" => @invalid_attrs})
    assert json_response(conn, 422)["errors"] != %{}
  end

  test "deletes chosen resource", %{authed: requestor} do
    user = user("test")
    conn = api_request(requestor, :delete, "/v1/users/#{user.id}")
    assert response(conn, 204)
    refute Repo.get(User, user.id)
  end

  test "cannot list users without permission", %{unauthed: requestor} do
    conn = api_request(requestor, :get, "/v1/users")
    assert conn.halted
    assert conn.status == 403
  end

  test "cannot create a user without permission", %{unauthed: requestor} do
    conn = api_request(requestor, :post, "/v1/users",
                       body: %{"user" => %{"username" => "tester",
                                           "first_name" => "Tester",
                                           "last_name" => "McTester",
                                           "email_address" => "tester@operable.io",
                                           "password" => "tester"}})
    assert conn.halted
    assert conn.status == 403
  end

  test "cannot retrieve a user without permission", %{unauthed: requestor} do
    user = user("tester")
    conn = api_request(requestor, :get, "/v1/users/#{user.id}")
    assert conn.halted
    assert conn.status == 403
  end

  test "cannot edit a user without permission", %{unauthed: requestor} do
    user = user("tester")
    conn = api_request(requestor, :put, "/v1/users/#{user.id}",
                       body: %{"user" => %{"name" => "administrator"}})
    assert conn.halted
    assert conn.status == 403
  end

  test "cannot delete a user without permission", %{unauthed: requestor} do
    user = user("tester")
    conn = api_request(requestor, :delete, "/v1/users/#{user.id}")
    assert conn.halted
    assert conn.status == 403
  end

end
