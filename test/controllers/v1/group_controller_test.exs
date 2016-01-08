defmodule Cog.V1.GroupControllerTest do
  use Cog.ModelCase
  use Cog.ConnCase

  alias Cog.Models.Group

  @valid_attrs %{name: "laliens"}
  @invalid_attrs %{name: -1}

  @bad_uuid "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"

  setup do
    # Requests handled by the role controller require this permission
    required_permission = permission("#{Cog.embedded_bundle}:manage_groups")

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

  test "lists all entries on index", %{authed: user} do
    conn = api_request(user, :get, "/v1/groups")
    assert json_response(conn, 200)["groups"] == []
  end

  test "shows chosen resource", %{authed: user} do
    group = group("aliens")
    conn = api_request(user, :get, "/v1/groups/#{group.id}")
    assert json_response(conn, 200)["group"] == %{"id" => group.id,
                                                  "name" => group.name}
  end

  test "does not show resource and instead throw error when id is nonexistent", %{authed: user} do
    error = catch_error(api_request(user, :get, "/v1/groups/#{@bad_uuid}"))
    assert %Ecto.NoResultsError{} = error
  end

  test "creates and renders resource when data is valid", %{authed: user} do
    conn = api_request(user, :post, "/v1/groups",
                       body: %{"group" => @valid_attrs})
    assert json_response(conn, 201)["group"]["id"]
    assert Repo.get_by(Group, @valid_attrs)
  end

  test "does not create resource and renders errors when data is invalid", %{authed: user} do
    conn = api_request(user, :post, "/v1/groups",
                       body: %{"group" => @invalid_attrs})
    assert json_response(conn, 422)["errors"] != %{}
  end

  test "updates and renders chosen resource when data is valid", %{authed: user} do
    group = group("predators")
    conn = api_request(user, :put, "/v1/groups/#{group.id}",
                       body: %{"group" => @valid_attrs})
    assert json_response(conn, 200)["group"]["id"] == group.id

    updated_group = Repo.get_by(Group, id: group.id)
    assert updated_group.name != group.name
    assert updated_group.name == @valid_attrs.name
  end

  test "does not update chosen resource and renders errors when data is invalid", %{authed: user} do
    group = group("aliens")
    conn = api_request(user, :put, "/v1/groups/#{group.id}",
                       body: %{"group" => @invalid_attrs})
    assert json_response(conn, 422)["errors"] != %{}
  end

  test "deletes chosen resource", %{authed: user} do
    group = group("aliens")
    conn = api_request(user, :delete, "/v1/groups/#{group.id}")
    assert response(conn, 204)
    refute Repo.get(Group, group.id)
  end

  test "cannot list groups without permission", %{unauthed: user} do
    conn = api_request(user, :get, "/v1/groups")
    assert conn.halted
    assert conn.status == 403
  end

  test "cannot create a group without permission", %{unauthed: user} do
    conn = api_request(user, :post, "/v1/groups",
                       body: %{"group" => %{"name" => "aliens"}})
    assert conn.halted
    assert conn.status == 403
  end

  test "cannot retrieve a group without permission", %{unauthed: user} do
    group = group("aliens")
    conn = api_request(user, :get, "/v1/groups/#{group.id}")
    assert conn.halted
    assert conn.status == 403
  end

  test "cannot edit a group without permission", %{unauthed: user} do
    group = group("aliens")
    conn = api_request(user, :put, "/v1/groups/#{group.id}",
                       body: %{"group" => %{"name" => "predators"}})
    assert conn.halted
    assert conn.status == 403
  end

  test "cannot delete a role without permission", %{unauthed: user} do
    group = group("aliens")
    conn = api_request(user, :delete, "/v1/groups/#{group.id}")
    assert conn.halted
    assert conn.status == 403
  end

end
