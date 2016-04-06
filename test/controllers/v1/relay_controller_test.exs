defmodule Cog.V1.RelayControllerTest do
  alias Ecto.DateTime

  use Cog.ModelCase
  use Cog.ConnCase

  alias Cog.Models.Relay
  alias Cog.Queries

  @create_attrs %{name: "test-1", token: "foo"}
  @update_attrs %{enabled: true, description: "My test"}

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
    conn = api_request(requestor, :post, "/v1/relays", body: %{"relay" => @create_attrs})
    relay_json = json_response(conn, 201)["relay"]
    assert relay_json["id"] != nil
    assert relay_json["groups"] == []
    refute relay_json["enabled"]
    assert Repo.get_by(Relay, id: relay_json["id"])
  end

  test "cannot create a relay without permission", %{unauthed: requestor} do
    conn = api_request(requestor, :post, "/v1/relays", body: %{"relay" => @create_attrs})
    assert conn.halted
    assert conn.status == 403
  end

  test "shows chosen resource", %{authed: requestor} do
    relay = relay("test-1", "foobar")
    conn = api_request(requestor, :get, "/v1/relays/#{relay.id}")
    assert %{"relay" => %{"id" => relay.id,
                          "name" => relay.name,
                          "enabled" => relay.enabled,
                          "groups" => [],
                          "description" => nil,
                          "inserted_at" => "#{DateTime.to_iso8601(relay.inserted_at)}",
                          "updated_at" => "#{DateTime.to_iso8601(relay.updated_at)}"}} == json_response(conn, 200)
  end

  test "cannot view relay without permission", %{unauthed: requestor} do
    relay = relay("test-1", "foobar")
    conn = api_request(requestor, :get, "/v1/relays/#{relay.id}")
    assert conn.halted
    assert conn.status == 403
  end

  test "deletes chosen resource", %{authed: requestor} do
    relay = relay("test-1", "foobar")
    conn = api_request(requestor, :delete, "/v1/relays/#{relay.id}")
    assert response(conn, 204)
    refute Repo.get(Relay, relay.id)
  end

  test "cannot delete relay without permission", %{unauthed: requestor} do
    relay = relay("test-1", "foobar")
    conn = api_request(requestor, :delete, "/v1/relays/#{relay.id}")
    assert conn.halted
    assert conn.status == 403
  end

  test "enable relay", %{authed: requestor} do
    relay = relay("test-1", "foobar")
    conn = api_request(requestor, :put, "/v1/relays/#{relay.id}",
                       body: %{"relay" => @update_attrs})
    updated = json_response(conn, 200)["relay"]
    assert updated["id"] == relay.id
    assert updated["name"] == relay.name
    assert updated["enabled"] == @update_attrs.enabled
    assert updated["description"] == @update_attrs.description
  end

  test "updated token changes token digest", %{authed: requestor} do
    relay = relay("test-1", "foobar")
    conn = api_request(requestor, :put, "/v1/relays/#{relay.id}",
                       body: %{"relay" => %{token: "barbaz"}})
    assert conn.status == 200
    updated = Repo.one!(Queries.Relay.for_id(relay.id))
    refute relay.token_digest == updated.token_digest
  end

  test "cannot enable relay without permission", %{unauthed: requestor} do
    relay = relay("test-1", "foobar")
    conn = api_request(requestor, :put, "/v1/relays/#{relay.id}",
                       body: %{"relay" => @update_attrs})
    assert conn.halted
    assert conn.status == 403
  end

  test "cannot change relay token without permission", %{unauthed: requestor} do
    relay = relay("test-1", "foobar")
    conn = api_request(requestor, :put, "/v1/relays/#{relay.id}",
                       body: %{"relay" => %{token: "blah"}})
    assert conn.halted
    assert conn.status == 403
  end

  test "fetching all resources", %{authed: requestor} do
    inserted = for {name, token} <- [{"test-1", "abc"}, {"test-2", "def"}] do
      relay(name, token)
    end
    conn = api_request(requestor, :get, "/v1/relays")
    relays = json_response(conn, 200)["relays"]
    assert length(relays) == 2
    inserted = Enum.sort(Enum.map(inserted, &(Map.get(&1, :id))))
    fetched = Enum.sort(Enum.map(relays, &(Map.get(&1, "id"))))
    assert inserted == fetched
  end

  test "inserting duplicate relay name fails", %{authed: requestor} do
    relay("test-1", "foobar")
    conn = api_request(requestor, :post, "/v1/relays", body: %{"relay" => @create_attrs})
    errors = json_response(conn, 422)["errors"]
    assert errors["name"] == ["has already been taken"]
  end

end
