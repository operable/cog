defmodule Integration.Commands.RelayGroupTest do
  use Cog.AdapterCase, adapter: "test"
  alias Cog.Support.ModelUtilities
  alias Cog.Models.RelayGroup
  alias Cog.Repo

  setup do
    user = user("vanstee", first_name: "Patrick", last_name: "Van Stee")
    |> with_chat_handle_for("test")
    |> with_permission("operable:manage_relays")

    {:ok, %{user: user}}
  end

  test "listing relay groups work", %{user: user} do
    # Create a few relays
    relay_group1 = ModelUtilities.relay_group("relay_group1")
    relay_group2 = ModelUtilities.relay_group("relay_group2")

    # Check to see that they show up in the list
    [foo1, foo2] = send_message(user, "@bot: operable:relay-group list")

    assert foo1.name == "relay_group1"
    assert foo1.id == relay_group1.id
    assert foo2.name == "relay_group2"
    assert foo2.id == relay_group2.id
  end

  test "listing with no relay groups returns an empty list", %{user: user} do
    payload = send_message(user, "@bot: operable:relay-group list")
    assert "Pipeline executed successfully, but no output was returned" = payload
  end

  test "listing is the default operation", %{user: user} do
    payload = send_message(user, "@bot: operable:relay-group")
    assert "Pipeline executed successfully, but no output was returned" = payload
  end

  test "renaming a relay group", %{user: user} do
    relay_group = ModelUtilities.relay_group("relay_group")

    [response] = send_message(user, "@bot: operable:relay-group rename relay_group rly_grp")

    assert response.relay_group.name == "rly_grp"

    relay_group = Repo.get(RelayGroup, relay_group.id)
    assert relay_group.name == "rly_grp"
  end

  test "creating a relay group", %{user: user} do
    [response] = send_message(user, "@bot: operable:relay-group create foogroup")
    assert response.name == "foogroup"

    relay_group = Repo.get(RelayGroup, response.id)
    assert relay_group.name == "foogroup"
  end

  test "deleting a relay group", %{user: user} do
    ModelUtilities.relay_group("relay_group")

    [response] = send_message(user, "@bot: operable:relay-group delete relay_group")

    assert response.name == "relay_group"

    fetched_relay_group = Repo.get(RelayGroup, response.id)
    assert fetched_relay_group == nil
  end

  test "adding relays to relay groups", %{user: user} do
    ModelUtilities.relay_group("relay_group")
    relay = ModelUtilities.relay("relay", "foo")

    [response] = send_message(user, "@bot: operable:relay-group member add relay_group relay")

    assert response.name == "relay_group"
    assert length(response.relays) == 1

    decoded_relay = hd(response.relays)
    assert decoded_relay.id == relay.id

    fetched_relay_group = Repo.get(RelayGroup, response.id)
    |> Repo.preload([:relays])
    assert fetched_relay_group.name == "relay_group"

    fetched_relay = hd(fetched_relay_group.relays)
    assert fetched_relay.id == relay.id
  end

  test "removing relays from relay groups", %{user: user} do
    relay_group = ModelUtilities.relay_group("relay_group")
    relay = ModelUtilities.relay("relay", "foo")
    ModelUtilities.add_relay_to_group(relay_group.id, relay.id)

    [response] = send_message(user, "@bot: operable:relay-group member remove relay_group relay")

    assert response.name == "relay_group"
    assert length(response.relays) == 0

    fetched_relay_group = Repo.get(RelayGroup, response.id)
    |> Repo.preload([:relays])
    assert fetched_relay_group.name == "relay_group"
    assert length(fetched_relay_group.relays) == 0
  end

  test "assigning bundles to relay groups", %{user: user} do
    ModelUtilities.relay_group("relay_group")
    bundle = ModelUtilities.bundle_version("bundle").bundle

    [response] = send_message(user, "@bot: operable:relay-group member assign relay_group bundle")

    assert response.name == "relay_group"
    assert length(response.bundles) == 1

    decoded_bundle = hd(response.bundles)
    assert decoded_bundle.name == "bundle"

    fetched_relay_group = Repo.get(RelayGroup, response.id)
    |> Repo.preload([:bundles])
    assert fetched_relay_group.name == "relay_group"

    fetched_bundle = hd(fetched_relay_group.bundles)
    assert fetched_bundle.id == bundle.id
  end

  test "unassigning bundles from relay groups", %{user: user} do
    relay_group = ModelUtilities.relay_group("relay_group")
    bundle = ModelUtilities.bundle_version("bundle").bundle
    ModelUtilities.assign_bundle_to_group(relay_group.id, bundle.id)

    [response] = send_message(user, "@bot: operable:relay-group member unassign relay_group bundle")

    assert response.name == "relay_group"
    assert length(response.bundles) == 0

    fetched_relay_group = Repo.get(RelayGroup, response.id)
    |> Repo.preload([:bundles])
    assert fetched_relay_group.name == "relay_group"
    assert length(fetched_relay_group.bundles) == 0
  end

  test "passing an unknown subcommand fails", %{user: user} do
    response = send_message(user, "@bot: operable:relay-group not-a-subcommand")
    assert_error_message_contains(response, "Whoops! An error occurred. Unknown subcommand 'not-a-subcommand'")
  end

end
