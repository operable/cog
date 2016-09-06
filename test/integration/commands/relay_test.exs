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
    [foo1, foo2] = send_message(user, "@bot: operable:relay list")

    assert foo1.name == "foo"
    assert foo1.id == relay1.id
    assert foo2.name == "foo2"
    assert foo2.id == relay2.id
  end

  test "listing relays with groups", %{user: user} do
    relay = ModelUtilities.relay("foo", "footoken")
    group = ModelUtilities.relay_group("foogroup")
    ModelUtilities.add_relay_to_group(group.id, relay.id)

    [response] = send_message(user, "@bot: operable:relay list --group")

    [decoded_group] = response.relay_groups
    assert decoded_group.name == group.name
  end

  test "updating a relay name", %{user: user} do
    relay = ModelUtilities.relay("foo", "footoken")

    [response] = send_message(user, "@bot: operable:relay update foo --name bar")

    assert response.name == "bar"

    relay = Repo.get(Relay, relay.id)
    assert relay.name == "bar"
  end

  test "getting information on a single relay works", %{user: user} do
    %Relay{} = ModelUtilities.relay("foo", "footoken")
    [response] = send_message(user, "@bot: operable:relay info foo")
    assert %{id: _,
             created_at: _,
             name: "foo",
             status: "disabled",
             relay_groups: []} = response
  end

  test "getting information on a non-existent relay fails", %{user: user} do
    response = send_message(user, "@bot: operable:relay info not-here")
    assert_error_message_contains(response, "Could not find 'relay' with the name 'not-here'")
  end

  test "getting information on a relay requires a relay name", %{user: user} do
    response = send_message(user, "@bot: operable:relay info")
    assert_error_message_contains(response, " Not enough args. Arguments required: exactly 1.")
  end

  test "getting information on more than one relay fails", %{user: user} do
    %Relay{} = ModelUtilities.relay("foo", "footoken")
    %Relay{} = ModelUtilities.relay("bar", "bartoken")
    response = send_message(user, "@bot: operable:relay info foo bar")
    assert_error_message_contains(response, "Too many args. Arguments required: exactly 1.")
  end

  test "getting information on a relay requires a string argument", %{user: user} do
    response = send_message(user, "@bot: operable:relay info 123")
    assert_error_message_contains(response, "Arguments must be strings")
  end

  test "passing an unknown subcommand fails", %{user: user} do
    response = send_message(user, "@bot: operable:relay not-a-subcommand")
    assert_error_message_contains(response, "Whoops! An error occurred. Unknown subcommand 'not-a-subcommand'")
  end

end
