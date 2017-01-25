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
    required_permission = permission("#{Cog.Util.Misc.embedded_bundle}:manage_users")

    # This user will be used to test the normal operation of the controller
    authed_user = user("cog")
    |> with_token

    # We add the user to a group and grant that group the appropriate permissions
    group = group("robots")
    role = role("robot_role")
    Groupable.add_to(authed_user, group)
    Permittable.grant_to(group, role)
    Permittable.grant_to(role, required_permission)

    # This user will be used to verify that the above permission is
    # indeed required for requests
    unauthed_user = user("sadpanda") |> with_token

    {:ok, [authed: authed_user,
           unauthed: unauthed_user,
           group: group]}
  end

  test "lists all entries on index", %{authed: requestor, unauthed: other} do
    conn = api_request(requestor, :get, "/v1/users")
    users_json = json_response(conn, 200)["users"]
    auth_id = requestor.id
    unauth_id = other.id
    assert [%{"id" => ^auth_id,
              "first_name" => "Cog",
              "last_name" => "McCog",
              "email_address" => "cog@operable.io",
              "groups" => [%{"name" => "robots"}],
              "chat_handles" => [],
              "username" => "cog"},
            %{"id" => ^unauth_id,
              "first_name" => "Sadpanda",
              "last_name" => "McSadpanda",
              "email_address" => "sadpanda@operable.io",
              "groups" => [],
              "chat_handles" => [],
              "username" => "sadpanda"}] = users_json |> sort_by("username")
  end

  test "shows the authed user's resource", %{authed: requestor, group: group} do
    conn = api_request(requestor, :get, "/v1/users/me")
    id = requestor.id
    username = requestor.username
    first_name = requestor.first_name
    last_name = requestor.last_name
    group_name = group.name
    email_address = requestor.email_address

    assert %{"user" => %{"id" => ^id,
                         "username" => ^username,
                         "first_name" => ^first_name,
                         "last_name" => ^last_name,
                         "groups" => [%{"name" => ^group_name}],
                         "chat_handles" => [],
                         "email_address" => ^email_address}} = json_response(conn, 200)
  end

  test "shows chosen resource", %{authed: requestor} do
    user = user("tester")
    conn = api_request(requestor, :get, "/v1/users/#{user.id}")
    assert %{"user" => %{"id" => user.id,
                         "username" => "tester",
                         "first_name" => "Tester",
                         "last_name" => "McTester",
                         "groups" => [],
                         "chat_handles" => [],
                         "email_address" => "tester@operable.io"}} == json_response(conn, 200)
  end

  test "renders the associated chat handles", %{authed: requestor} do
    user = user("tester") |> with_chat_handle_for("test") |> Repo.preload(:chat_handles)
    [chat_handle] = user.chat_handles
    conn = api_request(requestor, :get, "/v1/users/#{user.id}")
    assert %{"user" => %{"id" => user.id,
                         "username" => "tester",
                         "first_name" => "Tester",
                         "last_name" => "McTester",
                         "groups" => [],
                         "chat_handles" => [%{
                            "id" => chat_handle.id,
                            "handle" => chat_handle.handle,
                            "chat_provider" => %{
                              "name" => "test",
                            },
                            "username" => "tester"
                         }],
                         "email_address" => "tester@operable.io"}} == json_response(conn, 200)
  end

  test "returns an error when a bad id is passed", %{authed: requestor} do
    conn = api_request(requestor, :get, "/v1/users/#{@bad_uuid}")
    assert "User not found" = json_response(conn, 404)["errors"]
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
                                                 "groups" => [],
                                                 "chat_handles" => [],
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

  test "cannot delete a user when they have triggers", %{authed: requestor} do
    user = user("user_with_triggers")
    trigger(%{name: "cannot-delete-the-user",
              pipeline: "echo 'NOPE'",
              as_user: "user_with_triggers"})

    conn = api_request(requestor, :delete, "/v1/users/#{user.id}")

    assert json_response(conn, 422)["errors"] ==  %{"triggers" => ["are still associated to this entry"]}
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

  test "retrieving groups for each user", %{authed: requestor, group: group} do
    conn = api_request(requestor, :get, "/v1/users")
    users_json = json_response(conn, 200)["users"]
    [first | _] = users_json
    assert length(first["groups"]) == 1
    [groups | _] = first["groups"]
    assert Map.fetch!(groups, "name") == group.name
    assert Map.fetch!(groups, "id") == group.id
  end

  test "retrieving groups a specific user belongs in", %{authed: requestor, group: group} do
    conn = api_request(requestor, :get, "/v1/users/#{requestor.id}")
    user_json = json_response(conn, 200)["user"]
    assert length(user_json["groups"]) == 1
    [groups | _] = user_json["groups"]
    assert Map.fetch!(groups, "name") == group.name
    assert Map.fetch!(groups, "id") == group.id
  end

  test "user updates their own information without manage_users permission" do
    tester = user("tester")
    |> with_token
    conn = api_request(tester, :put, "/v1/users/#{tester.id}",
                       body: %{"user" => @valid_attrs})
    new_user = json_response(conn, 200)["user"]
    assert new_user == %{"id" => tester.id,
                         "username" => @valid_attrs.username,
                         "first_name" => @valid_attrs.first_name,
                         "email_address" => @valid_attrs.email_address,
                         "groups" => [],
                         "chat_handles" => [],
                         "last_name" => @valid_attrs.last_name}
  end

  test "user can get their own information without manage_users permission" do
    tester = user("tester")
    |> with_token
    conn = api_request(tester, :get, "/v1/users/#{tester.id}")
    new_user = json_response(conn, 200)["user"]
    assert new_user == %{"id" => tester.id,
                         "username" => tester.username,
                         "first_name" => tester.first_name,
                         "email_address" => tester.email_address,
                         "groups" => [],
                         "chat_handles" => [],
                         "last_name" => tester.last_name}
  end

  test "retrieving roles for each user", %{authed: requestor, unauthed: unauthed} do
    group = group("other_robots")
    Groupable.add_to(unauthed, group)
    role = role("take-over")
    Permittable.grant_to(group, role)
    permission = permission("site:world")
    Permittable.grant_to(role, permission)

    conn = api_request(requestor, :get, "/v1/users?username=#{unauthed.username}")
    user_json = json_response(conn, 200)

    assert %{"id" => unauthed.id,
             "email_address" => unauthed.email_address,
             "username" => unauthed.username,
             "first_name" => unauthed.first_name,
             "last_name" => unauthed.last_name,
             "groups" => [%{"id" => group.id,
                            "name" => group.name,
                            "roles" => [%{"id" => role.id,
                                          "name" => role.name,
                                          "permissions" => [%{"id" => permission.id,
                                                              "name" => "world",
                                                              "bundle" => "site"}]
                            }]
                        }],
              "chat_handles" => []
              } == user_json["user"]
  end

end
