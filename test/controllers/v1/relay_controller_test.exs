defmodule Cog.V1.RelayControllerTest do
  alias Ecto.DateTime

  use Cog.ModelCase
  use Cog.ConnCase

  alias Cog.Models.Relay
  alias Cog.Relay.Relays
  alias Cog.FakeRelay
  alias Cog.Queries

  @create_attrs %{name: "test-1", token: "foo"}
  @update_attrs %{enabled: true, description: "My test"}
  @disable_attrs %{@update_attrs | enabled: false}

  setup do
    # Requests handled by the role controller require this permission
    required_permission = permission("#{Cog.Util.Misc.embedded_bundle}:manage_relays")

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

  test "can create a relay with a user-defined ID", %{authed: requestor} do
    uuid = Ecto.UUID.generate
    params = Map.put(@create_attrs, :id, uuid)
    conn = api_request(requestor, :post, "/v1/relays", body: %{"relay" => params})
    relay_json = json_response(conn, 201)["relay"]
    assert relay_json["id"] == uuid
    assert Repo.get_by(Relay, id: uuid)
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

  test "deleted relays are removed from the tracker", %{authed: requestor} do
    # We create a relay and add a bundle to it so we can query for it in
    # 'Cog.Relay.Relays'
    {relay, bundle_version, _relay_group} = create_relay_bundle_and_group("deleted-relay", relay_opts: [enabled: true])

    # We shouldn't see any relays running our bundle yet, because the relay
    # has not yet announced it's presence.
    assert Relays.relays_running(bundle_version.bundle.name, bundle_version.version) == []

    # Relays don't show up as available unless they are online and enabled.
    # FakeRelay lets us send announcement messages like a real relay, so Cog
    # will add the relay to the available relays list.
    FakeRelay.announce(relay)

    # After announcing, our relay should be online and enabled since we created
    # it enabled.
    assert Relays.relays_running(bundle_version.bundle.name, bundle_version.version) == [relay.id]

    # This should delete the relay
    conn = api_request(requestor, :delete, "/v1/relays/#{relay.id}")

    # Confirm that the api thinks the relay has been deleted
    assert response(conn, 204)

    # And that the relay is no longer in the db
    refute Repo.get(Relay, relay.id)

    # And finally that the tracker is not reporting the relay as running the bundle
    assert Relays.relays_running(bundle_version.bundle.name, bundle_version.version) == []
  end

  test "relays are enabled in more than just name", %{authed: requestor} do
    # We create a relay and add a bundle to it so we can query for it in
    # 'Cog.Relay.Relays'
    {relay, bundle_version, _relay_group} = create_relay_bundle_and_group("enable-relay")

    # We shouldn't see any relays running our bundle yet, because the relay
    # has not yet announced it's presence.
    assert Relays.relays_running(bundle_version.bundle.name, bundle_version.version) == []

    # Relays don't show up as available unless they are online and enabled.
    # FakeRelay lets us send announcement messages like a real relay, so Cog
    # will add the relay to the available relays list.
    FakeRelay.announce(relay)

    # After announcing, our relay should be online but it still won't show up,
    # because we haven't enabled it yet.
    assert Relays.relays_running(bundle_version.bundle.name, bundle_version.version) == []

    # This should enable our relay
    conn = api_request(requestor, :put, "/v1/relays/#{relay.id}",
                       body: %{"relay" => @update_attrs})
    # Confirm that the api thinks the relay is enabled
    updated = json_response(conn, 200)["relay"]
    assert updated["enabled"] == @update_attrs.enabled

    # Now if we check for relays_running we should see our relay
    assert Relays.relays_running(bundle_version.bundle.name, bundle_version.version) == [relay.id]
  end

  test "relays are disabled in more than just name", %{authed: requestor} do
    # We create a relay and add a bundle to it so we can query for it in
    # 'Cog.Relay.Relays'
    {relay, bundle_version, _relay_group} = create_relay_bundle_and_group("disable-relay", relay_opts: [enabled: true])

    # We shouldn't see any relays running our bundle yet, because the relay
    # has not yet announced it's presence.
    assert Relays.relays_running(bundle_version.bundle.name, bundle_version.version) == []

    # Relays don't show up as available unless they are online and enabled.
    # FakeRelay lets us send announcement messages like a real relay, so Cog
    # will add the relay to the available relays list.
    FakeRelay.announce(relay)

    # After announcing, our relay should be online and enabled since we created
    # it enabled.
    assert Relays.relays_running(bundle_version.bundle.name, bundle_version.version) == [relay.id]

    # This should disable our relay
    conn = api_request(requestor, :put, "/v1/relays/#{relay.id}",
                       body: %{"relay" => @disable_attrs})
    # Confirm that the api thinks the relay is disabled
    updated = json_response(conn, 200)["relay"]
    assert updated["enabled"] == @disable_attrs.enabled

    # Now if we check for relays_running we should see nothing again
    assert Relays.relays_running(bundle_version.bundle.name, bundle_version.version) == []
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

  test "cannot update the ID of an existing relay", %{authed: requestor} do
    new_uuid = Ecto.UUID.generate
    relay = relay("test-1", "foobar")
    conn = api_request(requestor, :put, "/v1/relays/#{relay.id}",
                       body: %{"relay" => %{id: new_uuid}})
    errors = json_response(conn, 422)["errors"]
    assert errors["id"] == ["cannot modify ID"]
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
