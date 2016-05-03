defmodule Integration.Commands.RelayTest do
  use Cog.AdapterCase, adapter: "test"
  alias Cog.Support.ModelUtilities
  alias Cog.Models.Relay
  alias Cog.Repo

  setup do
    user = user("vanstee", first_name: "Patrick", last_name: "Van Stee")
    |> with_chat_handle_for("test")
    |> with_permission("operable:manage_relays")

    {:ok, %{user: user}}
  end

  test "listing relays", %{user: user} do
    # Create a few relays
    relay1 = ModelUtilities.relay("foo", "footoken")
    relay2 = ModelUtilities.relay("foo2", "otherfootoken")

    # Check to see that they show up in the list
    response = send_message(user, "@bot: operable:relay list")

    [foo1, foo2] = decode_payload(response)
    assert foo1.name == "foo"
    assert foo1.id == relay1.id
    assert foo2.name == "foo2"
    assert foo2.id == relay2.id
  end

  test "listing relays with groups", %{user: user} do
    relay = ModelUtilities.relay("foo", "footoken")
    group = ModelUtilities.relay_group("foogroup")
    ModelUtilities.add_relay_to_group(group.id, relay.id)

    response = send_message(user, "@bot: operable:relay list --group")

    [decoded] = decode_payload(response)
    [decoded_group] = decoded.relay_groups
    assert decoded_group.name == group.name
  end

  test "updating a relay name", %{user: user} do
    relay = ModelUtilities.relay("foo", "footoken")

    response = send_message(user, "@bot: operable:relay update foo --name bar")

    [decoded] = decode_payload(response)
    assert decoded.relay.name == "bar"

    relay = Repo.get(Relay, relay.id)
    assert relay.name == "bar"
  end
end
