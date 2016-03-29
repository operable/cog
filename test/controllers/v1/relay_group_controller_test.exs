defmodule Cog.V1.RelayGroupControllerTest do
  alias Ecto.DateTime

  use Cog.ModelCase
  use Cog.ConnCase

  alias Cog.Models.RelayGroup
  alias Cog.Repo

  @create_attrs %{name: "test-1"}

  setup do
    # Requests handled by the role controller require this permission
    required_permission = permission("#{Cog.embedded_bundle}:manage_relays")

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

  test "creates and renders resource when data is valid", %{authed: requestor} do
    conn = api_request(requestor, :post, "/v1/relay_groups", body: %{"relay_group" => @create_attrs})
    relay_group = json_response(conn, 201)["relay_group"]
    assert relay_group["id"] != nil
    assert relay_group["relays"] == []
    assert Repo.get_by(RelayGroup, id: relay_group["id"])
  end

  test "cannot create a relay_group without permission", %{unauthed: requestor} do
    conn = api_request(requestor, :post, "/v1/relay_groups", body: %{"relay" => @create_attrs})
    assert conn.halted
    assert conn.status == 403
  end

  test "shows chosen resource", %{authed: requestor} do
    relay_group = relay_group("test-group-1")
    conn = api_request(requestor, :get, "/v1/relay_groups/#{relay_group.id}")
    assert %{"relay_group" => %{"id" => relay_group.id,
                                "name" => relay_group.name,
                                "relays" => [],
                                "inserted_at" => "#{DateTime.to_iso8601(relay_group.inserted_at)}",
                                "updated_at" => "#{DateTime.to_iso8601(relay_group.updated_at)}"}} == json_response(conn, 200)
  end

  test "cannot view relay_group without permission", %{unauthed: requestor} do
    relay_group = relay_group("test-group-1")
    conn = api_request(requestor, :get, "/v1/relay_groups/#{relay_group.id}")
    assert conn.halted
    assert conn.status == 403
  end

  test "deletes chosen resource", %{authed: requestor} do
    relay_group = relay_group("test-group-1")
    conn = api_request(requestor, :delete, "/v1/relay_groups/#{relay_group.id}")
    assert response(conn, 204)
    refute Repo.get(RelayGroup, relay_group.id)
  end

  test "cannot delete relay_group without permission", %{unauthed: requestor} do
    relay_group = relay_group("test-group-1")
    conn = api_request(requestor, :delete, "/v1/relay_groups/#{relay_group.id}")
    assert conn.halted
    assert conn.status == 403
  end

  test "update relay_group name", %{authed: requestor} do
    relay_group = relay_group("test-group-1")
    conn = api_request(requestor, :put, "/v1/relay_groups/#{relay_group.id}",
                       body: %{"relay_group" => %{"name" => "prod-group-2"}})
    updated = json_response(conn, 200)["relay_group"]
    assert updated["id"] == relay_group.id
    refute updated["name"] == relay_group.name
    assert updated["name"] == "prod-group-2"
  end

  test "cannot update relay_group without permission", %{unauthed: requestor} do
    relay_group = relay_group("test-group-1")
    conn = api_request(requestor, :put, "/v1/relay_groups/#{relay_group.id}",
                       body: %{"relay_group" => %{"name" => "prod-group-2"}})
    assert conn.halted
    assert conn.status == 403
  end

  test "fetching all resources", %{authed: requestor} do
    inserted = for name <- ["test-group-1", "test-group-2", "test-group-3"] do
      relay_group(name)
    end
    conn = api_request(requestor, :get, "/v1/relay_groups")
    relay_groups = json_response(conn, 200)["relay_groups"]
    assert length(relay_groups) == 3
    inserted = Enum.sort(Enum.map(inserted, &(Map.get(&1, :id))))
    fetched = Enum.sort(Enum.map(relay_groups, &(Map.get(&1, "id"))))
    assert inserted == fetched
  end

  test "inserting duplicate relay_group name fails", %{authed: requestor} do
    relay_group("test-1")
    conn = api_request(requestor, :post, "/v1/relay_groups", body: %{"relay_group" => @create_attrs})
    errors = json_response(conn, 422)["errors"]
    assert errors["name"] == ["has already been taken"]
  end

end
