defmodule Cog.V1.RelayGroupMembershipControllerTest do

  use Cog.ModelCase
  use Cog.ConnCase

  @relay_create_attrs %{name: "test-relay-1", token: "foo"}
  @relay_group_create_attrs %{name: "test-relay-group-1"}

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

  test "shows chosen resource", %{authed: requestor} do
    relay = relay("test-relay-1", "foo")
    relay_group = relay_group("test-relay-group-1")
    add_relay_to_group(relay_group.id, relay.id)
    conn = api_request(requestor, :get, "/v1/relay_groups/#{relay_group.id}/relays")
    relays = json_response(conn, 200)["relays"]
    assert length(relays) == 1
    assert relays == [%{"id" => relay.id,
                        "name" => relay.name}]
  end

  test "relay group includes member relays", %{authed: requestor} do
    relay = relay("test-relay-1", "foo")
    relay_group = relay_group("test-relay-group-1")
    add_relay_to_group(relay_group.id, relay.id)
    conn = api_request(requestor, :get, "/v1/relay_groups/#{relay_group.id}")
    fetched = json_response(conn, 200)["relay_group"]
    assert relay_group.id == fetched["id"]
    assert relay_group.name == fetched["name"]
    assert length(fetched["relays"]) == 1
    member = Enum.at(fetched["relays"], 0)
    assert member["id"] == relay.id
    assert member["name"] == relay.name
  end

  test "relay includes relay_group memberships", %{authed: requestor} do
    relay = relay("test-relay-1", "foo")
    relay_groups = (for name <- ["test-relay-group-1", "test-relay-group-2"] do
      rg = relay_group(name)
      add_relay_to_group(rg.id, relay.id)
      {rg.id, rg.name}
    end) |> Enum.sort

    conn = api_request(requestor, :get, "/v1/relays/#{relay.id}")
    fetched = json_response(conn, 200)["relay"]

    assert relay.id == fetched["id"]
    assert relay.name == fetched["name"]
    assert length(relay_groups) == length(fetched["groups"])
    fetched_groups = fetched["groups"]
    |> Enum.map(&({Map.get(&1, "id"), Map.get(&1, "name")}))
    |> Enum.sort
    assert relay_groups == fetched_groups
  end

  test "adding relays via REST endpoint", %{authed: requestor} do
    relay_group = relay_group("test-relay-group-3")
    relays = for name <- ["test-relay-1", "test-relay-2", "test-relay-3"] do
      relay(name, "foo")
    end
    relay_ids = Enum.sort(Enum.map(relays, &(&1.id)))
    conn = api_request(requestor, :post, "/v1/relay_groups/#{relay_group.id}/membership",
                       body: %{"relays" => %{"add" => relay_ids}})
    updated = json_response(conn, 200)["relay_group"]
    assert updated["id"] == relay_group.id
    assert updated["name"] == relay_group.name
    assert length(updated["relays"]) == length(relay_ids)
    assert relay_ids == Enum.sort(Enum.map(updated["relays"], &(Map.get(&1, "id"))))
  end

  test "removing relays via REST endpoint", %{authed: requestor} do
    relay_group = relay_group("test-relay-group-3")
    relays = for name <- ["test-relay-1", "test-relay-2", "test-relay-3"] do
      relay(name, "foo")
    end
    for relay <- relays do
      add_relay_to_group(relay_group.id, relay.id)
    end
    relay_ids = Enum.sort(Enum.map(relays, &(&1.id)))
    to_remove = tl(relay_ids)
    conn = api_request(requestor, :post, "/v1/relay_groups/#{relay_group.id}/membership",
                       body: %{"relays" => %{"remove" => to_remove}})
    updated = json_response(conn, 200)["relay_group"]
    assert length(updated["relays"]) == 1
    [remaining] = updated["relays"]
    assert remaining["id"] == hd(relay_ids)
  end


end
