defmodule Integration.RuleTest do
  use Cog.AdapterCase, adapter: "test"

  setup do
    user = user("belf", first_name: "Buddy", last_name: "Elf")
    |> with_chat_handle_for("test")
    |> with_permission("operable:manage_commands")

    {:ok, %{user: user}}
  end

  ########################################################################
  # General

  test "error when unknown options for rules command", %{user: user} do
    assert_error(user, "@bot: operable:rules --doit 'when command is operable:st-echo must have operable:st-echo'",
                 "@belf Whoops! An error occurred. \n* You must specify either an `--add`, `--drop`, or `--list` action\n\n")
  end

  test "error when no action is specified", %{user: user} do
    assert_error(user, "@bot: operable:rules",
                 "@belf Whoops! An error occurred. \n* You must specify either an `--add`, `--drop`, or `--list` action\n\n")
  end

  test "error when too many actions are specified", %{user: user} do
    assert_error(user, "@bot: operable:rules --add --drop",
                 "@belf Whoops! An error occurred. \n* You must specify only one of `--add`, `--drop`, or `--list` as an action\n\n")
  end

  ########################################################################
  # Add

  test "adding a rule for a command", %{user: user} do
    permission("site:permission")

    response = interact(user, "@bot: operable:rules --add 'when command is operable:st-echo must have site:permission'")

    assert_uuid(response["id"])
    assert response["command"] == "operable:st-echo"
    assert response["rule"] == "when command is operable:st-echo must have site:permission"
  end

  test "error when specifying too many arguments for manual rule creation", %{user: user} do
    assert_error(user, "@bot: operable:rules --add \"blah\" \"blah\"",
                 "@belf Whoops! An error occurred. \n* The `--add` action expects 1 argument\n\n")
  end

  test "error when rule argument is not a string", %{user: user} do
    assert_error(user, "@bot: operable:rules --add 123",
                 "@belf Whoops! An error occurred. \n* The argument `<expression>` must be a string; you gave `123`\n\n")
  end

  test "error when creating rule for an unrecognized command", %{user: user} do
    permission("site:permission")
    assert_error(user, "@bot: operable:rules --add --for-command=\"not_really:a_command\" --permission=\"site:permission\"",
                 "@belf Whoops! An error occurred. \n* Could not find command `not_really:a_command`\n\n")
  end

  test "error when creating rule for an unqualified command", %{user: user} do
    permission("site:permission")
    assert_error(user, "@bot: operable:rules --add --for-command=\"something\" --permission=\"site:permission\"",
                 "@belf Whoops! An error occurred. \n* The value of the `--for-command` option must be a bundle-qualified command, like `operable:help`\n\n")
  end

  test "error when creating a rule without specifying a command", %{user: user} do
    permission("site:permission")
    assert_error(user, "@bot: operable:rules --add --permission=\"site:permission\"",
                 "@belf Whoops! An error occurred. \n* You must specify a `--for-command` option\n\n")
  end

  test "error when creating a rule without specifying a permission", %{user: user} do
    assert_error(user, "@bot: operable:rules --add --for-command=\"operable:st-echo\"",
                 "@belf Whoops! An error occurred. \n* You must specify a `--permission` option\n\n")
  end

  test "error when creating a rule specifying a non-string permission", %{user: user} do
    assert_error(user, "@bot: operable:rules --add --for-command=\"operable:st-echo\" --permission=123",
                 "@belf Whoops! An error occurred. Type Error: `123` is not of type `string`")
  end

  test "error when creating a rule specifying an unqualified permission", %{user: user} do
    assert_error(user, "@bot: operable:rules --add --for-command=\"operable:st-echo\" --permission=foo",
                 "@belf Whoops! An error occurred. \n* The value of the `--permission` option must be a fully-qualified permission, like `site:admin`\n\n")
  end

  test "error when creating rule with an unrecognized permission", %{user: user} do
    assert_error(user, "@bot: operable:rules --add --for-command=\"operable:st-echo\" --permission=\"site:permission\"",
                 "@belf Whoops! An error occurred. \n* Could not find permission `site:permission`\n\n")
  end

  test "error when creating a rule specifying a permission from an unacceptable namespace", %{user: user} do
    permission("foo:bar")
    assert_error(user, "@bot: operable:rules --add --for-command=\"operable:st-echo\" --permission=\"foo:bar\"",
                 "@belf Whoops! An error occurred. \n* The namespace of the permission must either be `site` or the bundle from which the command comes\n\n")
  end

  test "error when creating a rule without specifying a command or a permission catches both errors", %{user: user} do
    assert_error(user, "@bot: operable:rules --add",
                 "@belf Whoops! An error occurred. \n* You must specify a `--for-command` option\n* You must specify a `--permission` option\n\n")
  end

  test "error when manually creating a rule with invalid syntax", %{user: user} do
    assert_error(user, "@bot: operable:rules --add \"this is totally not a valid rule\"",
                 "@belf Whoops! An error occurred. \n* Invalid rule: (Line: 1, Col: 0) syntax error before: \"this\".\n\n")
  end

  ########################################################################
  # Drop

  test "dropping a rule via the command name", %{user: user} do
    response = interact(user, "@bot: operable:rules --drop --for-command=\"operable:st-echo\"")

    assert_uuid(response["id"])
    assert response["command"] == "operable:st-echo"
    assert response["rule"] == "when command is operable:st-echo must have operable:st-echo"

    assert Cog.Queries.Command.rules_for_cmd("operable:st-echo") |> Cog.Repo.all == []
  end

  test "dropping a rule via a rule id", %{user: user} do
    # Get an ID we can use to drop
    response = interact(user, "@bot: operable:rules --list --for-command=\"operable:st-echo\"")
    id = response["id"]

    response = interact(user, "@bot: operable:rules --drop --id=\"#{id}\"")

    # TODO: why is this response not a list?
    assert response["id"] == id
    assert response["command"] == "operable:st-echo"
    assert response["rule"] == "when command is operable:st-echo must have operable:st-echo"

    assert Cog.Queries.Command.rules_for_cmd("operable:st-echo") |> Cog.Repo.all == []
  end

  test "error when dropping rule with non-string id", %{user: user} do
    assert_error(user, "@bot: operable:rules --drop --id=123",
                 "@belf Whoops! An error occurred. Type Error: `123` is not of type `string`")
  end

  test "error when dropping rule with non-UUID string id", %{user: user} do
    assert_error(user, "@bot: operable:rules --drop --id=\"not-a-uuid\"",
                 "@belf Whoops! An error occurred. \n* The option `id` must be a UUID; you gave `\"not-a-uuid\"`\n\n")
  end

  test "error when dropping rule with unknown id", %{user: user} do
    assert_error(user, "@bot: operable:rules --drop --id=\"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee\"",
                 "@belf Whoops! An error occurred. \n* There are no rules with the ID `aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee`\n\n")
  end

  test "error when dropping rule without `--for-command` or `--id` option", %{user: user} do
    assert_error(user, "@bot: operable:rules --drop",
                 "@belf Whoops! An error occurred. \n* The `--drop` action expects either an `--id` option or a `--for-command` option\n\n")
  end

  test "error when dropping rules by command with an unrecognized command", %{user: user} do
    assert_error(user, "@bot: operable:rules --drop --for-command=\"not_really:a_command\"",
                 "@belf Whoops! An error occurred. \n* Could not find command `not_really:a_command`\n\n")
  end

  test "error when dropping rules for an unqualified command", %{user: user} do
    assert_error(user, "@bot: operable:rules --drop --for-command=\"something\"",
                 "@belf Whoops! An error occurred. \n* The value of the `--for-command` option must be a bundle-qualified command, like `operable:help`\n\n")
  end

  ########################################################################
  # List

  test "listing rules", %{user: user} do
    response = interact(user, "@bot: operable:rules --list --for-command=\"operable:st-echo\"")

    assert response["command"] == "operable:st-echo"
    assert response["rule"] == "when command is operable:st-echo must have operable:st-echo"
  end

  test "error when listing rules for an unrecognized command", %{user: user} do
    assert_error(user, "@bot: operable:rules --list --for-command=\"not_really:a_command\"",
                 "@belf Whoops! An error occurred. \n* Could not find command `not_really:a_command`\n\n")
  end

  test "error when listing rules for an unqualified command", %{user: user} do
    assert_error(user, "@bot: operable:rules --list --for-command=\"something\"",
                 "@belf Whoops! An error occurred. \n* The value of the `--for-command` option must be a bundle-qualified command, like `operable:help`\n\n")
  end

  ########################################################################
  # Helper Functions

  # If the command succeeded, the response should be valid JSON; if
  # so, go ahead and transform that into an Elixir data structures.
  #
  # Otherwise, it'll be an error message; if so, return _that_.
  defp parsed_response(response) do
    raw_response = response["data"]["response"]
    case Poison.decode(raw_response) do
      {:ok, map} ->
        map
      {:error, _} ->
        raw_response
    end
  end

  defp assert_uuid(maybe_uuid),
    do: assert Cog.UUID.is_uuid?(maybe_uuid)

  defp interact(user, pipeline),
    do: send_message(user, pipeline) |> parsed_response

  defp assert_error(user, pipeline, expected_message) when is_binary(expected_message),
    do: assert interact(user, pipeline) == expected_message

end
