defmodule Cog.Test.Commands.RelayGroupTest do
  use Cog.CommandCase, command_module: Cog.Commands.RelayGroup

  import Cog.Support.ModelUtilities, only: [relay_group: 1,
                                            relay: 2,
                                            add_relay_to_group: 2,
                                            bundle_version: 1,
                                            assign_bundle_to_group: 2]
  alias Cog.Repository.RelayGroups

  test "listing relay groups work" do
    relay_group("relay_group1")
    relay_group("relay_group2")

    response = new_req(args: ["list"])
               |> send_req()
               |> unwrap()

    assert([%{name: "relay_group1"},
            %{name: "relay_group2"}] = response)
  end

  test "listing with no relay groups returns an empty list" do
    payload = new_req(args: ["list"])
              |> send_req()
              |> unwrap()

    assert([] == payload)
  end

  test "listing is the default operation" do
    payload = new_req()
              |> send_req()
              |> unwrap()

    assert([] == payload)
  end

  test "renaming a relay group" do
    %{id: id} = relay_group("relay_group")

    response = new_req(args: ["rename", "relay_group", "rly_grp"])
               |> send_req()
               |> unwrap()

    assert(%{old_name: "relay_group",
             relay_group: %{name: "rly_grp",
                            id: ^id}} = response)

    relay_group = RelayGroups.by_id!(id)
    assert(relay_group.name == "rly_grp")
  end

  test "creating a relay group" do
    response = new_req(args: ["create", "foogroup"])
               |> send_req()
               |> unwrap()

    assert(%{name: "foogroup"} = response)

    relay_group = RelayGroups.by_id!(response.id)
    assert(relay_group.name == "foogroup")
  end

  test "deleting a relay group" do
    relay_group("relay_group")

    response = new_req(args: ["delete", "relay_group"])
               |> send_req()
               |> unwrap()

    assert(%{name: "relay_group"} = response)

    relay_group = RelayGroups.by_id(response.id)
                  |> unwrap_error()

    assert(relay_group == :not_found)
  end

  test "adding relays to relay groups" do
    relay_group("relay_group")
    relay("relay", "foo")

    response = new_req(args: ["member", "add", "relay_group", "relay"])
               |> send_req()
               |> unwrap()

    assert(%{name: "relay_group",
             relays: [%{name: "relay"}]} = response)

    relay_group = RelayGroups.by_id!(response.id)
    assert(%{name: "relay_group",
             relays: [%{name: "relay"}]} = relay_group)
  end

  test "removing relays from relay groups" do
    relay_group = relay_group("relay_group")
    relay = relay("relay", "foo")
    add_relay_to_group(relay_group.id, relay.id)

    response = new_req(args: ["member", "remove", "relay_group", "relay"])
               |> send_req()
               |> unwrap()

    assert(%{name: "relay_group",
             relays: []} = response)

    relay_group = RelayGroups.by_id!(response.id)
    assert(%{name: "relay_group",
             relays: []} = relay_group)
  end

  test "assigning bundles to relay groups" do
    relay_group("relay_group")
    bundle_version("bundle").bundle

    response = new_req(args: ["member", "assign", "relay_group", "bundle"])
               |> send_req()
               |> unwrap()

    assert(%{name: "relay_group",
             bundles: [%{name: "bundle"}]} = response)

    relay_group = RelayGroups.by_id!(response.id)
    assert(%{name: "relay_group",
             bundles: [%{name: "bundle"}]} = relay_group)
  end

  test "unassigning bundles from relay groups" do
    relay_group = relay_group("relay_group")
    bundle = bundle_version("bundle").bundle
    assign_bundle_to_group(relay_group.id, bundle.id)

    response = new_req(args: ["member", "unassign", "relay_group", "bundle"])
               |> send_req()
               |> unwrap()

    assert(%{name: "relay_group",
             bundles: []} = response)

    relay_group = RelayGroups.by_id!(response.id)
    assert(%{name: "relay_group",
             bundles: []} = relay_group)
  end

  test "passing an unknown subcommand fails" do
    error = new_req(args: ["not-a-subcommand"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Unknown subcommand 'not-a-subcommand'")
  end

end
