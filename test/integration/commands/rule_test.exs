defmodule Integration.Commands.RuleTest do
  use Cog.AdapterCase, adapter: "test"

  alias Cog.Models.Rule
  alias Cog.Repository.Rules

  require Ecto.Query

  @bad_uuid "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"

  setup do
    user = user("belf", first_name: "Buddy", last_name: "Elf")
    |> with_chat_handle_for("test")
    |> with_permission("operable:manage_commands")

    {:ok, %{user: user}}
  end

  ########################################################################
  # List

  test "listing rules", %{user: user} do
    [response] = send_message(user, "@bot: rule -c operable:st-echo")

    assert response[:command] == "operable:st-echo"
    assert response[:rule] == "when command is operable:st-echo must have operable:st-echo"
  end

  test "error when listing rules for an unrecognized command", %{user: user} do
    assert_error(user, "@bot: rule -c not_really:a_command",
                 ~s(Whoops! An error occurred. Command "not_really:a_command" could not be found))
  end

  test "listing rules for a disabled command fails", %{user: user} do
    # Create a bundle that we won't enable
    {:ok, _version} = Cog.Repository.Bundles.install(
      %{"name" => "test-bundle",
        "version" => "1.0.0",
        "config_file" => %{
          "name" => "test-bundle",
          "version" => "1.0.0",
          "commands" => %{"hola" => %{"rules" => ["when command is test-bundle:hola allow"]}}}})

    assert_error(user, "@bot: rule -c test-bundle:hola",
              ~s(Whoops! An error occurred. test-bundle:hola is not enabled. Enable a bundle version and try again))
  end

  ########################################################################
  # Add

  test "adding a rule for a command", %{user: user} do
    permission("site:permission")

    [response] = send_message(user, ~s(@bot: rule create "when command is operable:st-echo must have site:permission"))

    assert_uuid(response[:id])
    assert response[:command] == "operable:st-echo"
    assert response[:rule] == "when command is operable:st-echo must have site:permission"
  end

  test "error when specifying too many arguments for manual rule creation", %{user: user} do
    assert_error(user, ~s(@bot: rule create "blah" "blah" "blah"),
                 "Whoops! An error occurred. Invalid args. Please pass between 1 and 2 arguments.")
  end

  test "error when creating rule for an unrecognized command", %{user: user} do
    permission("site:permission")
    assert_error(user, ~s(@bot: rule create "not_really:a_command" "site:permission"),
                 ~s(Whoops! An error occurred. Could not create rule: Unrecognized command "not_really:a_command"))
  end

  test "error when creating rule with an unrecognized permission", %{user: user} do
    assert_error(user, ~s(@bot: rule create "operable:st-echo" "site:permission"),
                 ~s(Could not create rule: Unrecognized permission "site:permission"))
  end

  test "error when creating a rule specifying a permission from an unacceptable namespace", %{user: user} do
    permission("foo:bar")
    assert_error(user, ~s(@bot: rule create "operable:st-echo" "foo:bar"),
                 ~s(Whoops! An error occurred. Could not create rule with permission outside of command bundle or the \"site\" namespace))
  end

  test "error when manually creating a rule with invalid syntax", %{user: user} do
    assert_error(user, ~s(@bot: rule create "this is totally not a valid rule"),
                 ~s{Whoops! An error occurred. Could not create rule: \"(Line: 1, Col: 0) syntax error before: \\"this\\".})
  end

  ########################################################################
  # Drop

  test "dropping a rule via a rule id", %{user: user} do
    # Get an ID we can use to drop
    [response] = send_message(user, "@bot: rule list -c operable:st-echo")
    id = response[:id]
    [response] = send_message(user, "@bot: rule delete #{id}")

    # TODO: why is this response not a list?
    assert response[:id] == id
    assert response[:command] == "operable:st-echo"
    assert response[:rule] == "when command is operable:st-echo must have operable:st-echo"

    rules = rules_for_command_name("operable:st-echo")
    assert rules == []
  end

  test "error when dropping rule with non-UUID string id", %{user: user} do
    assert_error(user, "@bot: rule delete not-a-uuid",
                 ~s(Whoops! An error occurred. Invalid UUID "not-a-uuid"))
  end

  test "error when dropping rule with unknown id", %{user: user} do
    assert_error(user, "@bot: rule delete #{@bad_uuid}",
                 ~s(Whoops! An error occurred. Rule "#{@bad_uuid}" could not be found))
  end

  ########################################################################

  test "retrieving a rule by ID works", %{user: user} do
    {:ok, %Rule{id: id}} = Rules.ingest("when command is operable:rule allow")
    [payload] = send_message(user, "@bot: operable:rule info #{id}")

    assert %{id: id,
             command_name: "operable:rule",
             rule: "when command is operable:rule allow"} == payload
  end

  test "retrieving a non-existent rule fails", %{user: user} do
    response = send_message(user, "@bot: operable:rule info #{@bad_uuid}")
    assert_error_message_contains(response, "Could not find 'rule' with the id '#{@bad_uuid}")
  end

  test "retrieving a rule requires an ID", %{user: user} do
    response = send_message(user, "@bot: operable:rule info")
    assert_error_message_contains(response, "Not enough args. Arguments required: exactly 1")
  end

  test "the ID given for retrieving a rule must be a string and a UUID", %{user: user} do
    response = send_message(user, "@bot: operable:rule info not_a_uuid")
    assert_error_message_contains(response, "Invalid UUID \"not_a_uuid\"")

    response = send_message(user, "@bot: operable:rule info 123")
    assert_error_message_contains(response, "Argument must be a string")
  end

  test "only one rule can be retrieved at a time", %{user: user} do
    {:ok, %Rule{id: rule_1_id}} = Rules.ingest("when command is operable:rule allow")
    {:ok, %Rule{id: rule_2_id}} = Rules.ingest("when command is operable:bundle allow")

    response = send_message(user, "@bot: operable:rule info #{rule_1_id} #{rule_2_id}")
    assert_error_message_contains(response, "Too many args. Arguments required: exactly 1")
  end

  ########################################################################

  test "passing an unknown subcommand fails", %{user: user} do
    response = send_message(user, "@bot: operable:rule not-a-subcommand")
    assert_error_message_contains(response, "Whoops! An error occurred. Unknown subcommand 'not-a-subcommand'")
  end

  ########################################################################
  # Helper Functions

  defp assert_uuid(maybe_uuid),
    do: assert Cog.UUID.is_uuid?(maybe_uuid)

  defp assert_error(user, pipeline, expected_message) when is_binary(expected_message),
    do: assert_error_message_contains(send_message(user, pipeline), expected_message)

  defp rules_for_command_name(command_name) do
    {:ok, command} = Cog.Models.Command.parse_name(command_name)
    Cog.Repo.all(Ecto.assoc(command, :rules) |> Ecto.Query.where(enabled: true))
  end
end
