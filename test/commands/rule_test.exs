defmodule Cog.Test.Commands.RuleTest do
  use Cog.CommandCase, command_module: Cog.Commands.Rule

  import Cog.Support.ModelUtilities, only: [permission: 1]
  alias Cog.Repository.Bundles
  alias Cog.Models.Rule
  alias Cog.Repository.Rules

  #require Ecto.Query

  @bad_uuid "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"

  describe "list" do

    setup :with_bundle

    test "listing rules" do
      response = new_req(options: %{"command" => "test-bundle:st-echo"})
                 |> send_req()
                 |> unwrap()

      assert([%{command: "test-bundle:st-echo",
                rule: "when command is test-bundle:st-echo must have test-bundle:st-echo"}] = response)
    end

    test "error when listing rules for an unrecognized command" do
      error = new_req(options: %{"command" => "not_really:a_command"})
              |> send_req()
              |> unwrap_error()

      assert(error == ~s(Command "not_really:a_command" could not be found))
    end

    @tag :with_disabled_bundle
    test "listing rules for a disabled command fails" do
      error = new_req(options: %{"command" => "test-bundle:st-echo"})
              |> send_req()
              |> unwrap_error()

      assert(error == ~s(test-bundle:st-echo is not enabled. Enable a bundle version and try again))
    end

  end

  describe "add" do

    setup :with_bundle

    test "adding a rule for a command" do
      permission("site:permission")

      response = new_req(args: ["create", "when command is test-bundle:st-echo must have site:permission"])
                 |> send_req()
                 |> unwrap()

      assert_uuid(response[:id])
      assert(%{command: "test-bundle:st-echo",
               rule: "when command is test-bundle:st-echo must have site:permission"} = response)
    end

    test "error when specifying too many arguments for manual rule creation" do
      error = new_req(args: ["create", "blah", "blah", "blah"])
              |> send_req()
              |> unwrap_error()

      assert(error == "Invalid args. Please pass between 1 and 2 arguments.")
    end

    test "error when creating rule for an unrecognized command" do
      permission("site:permission")

      error = new_req(args: ["create", "not_really:a_command", "site:permission"])
              |> send_req()
              |> unwrap_error()

      assert(error == ~s(Could not create rule: Unrecognized command "not_really:a_command"))
    end

    test "error when creating rule with an unrecognized permission" do
      error = new_req(args: ["create", "test-bundle:st-echo", "site:permission"])
              |> send_req()
              |> unwrap_error()

      assert(error == ~s(Could not create rule: Unrecognized permission "site:permission"))
    end

    test "error when creating a rule specifying a permission from an unacceptable namespace" do
      permission("foo:bar")

      error = new_req(args: ["create", "test-bundle:st-echo", "foo:bar"])
              |> send_req()
              |> unwrap_error()

      assert(error == ~s(Could not create rule with permission outside of command bundle or the \"site\" namespace))
    end

    test "error when manually creating a rule with invalid syntax" do
      error = new_req(args: ["create",  "this is totally not a valid rule"])
              |> send_req()
              |> unwrap_error()

      assert(error == ~s{Could not create rule: \"(Line: 1, Col: 0) syntax error before: \\"this\\".\"})
    end
  end

  describe "drop" do

    setup :with_bundle

    test "dropping a rule via a rule id" do
      # Get an ID we can use to drop
      [%{id: id}] = Rules.rules_for_command("test-bundle:st-echo")
                    |> unwrap()

      response = new_req(args: ["delete", id])
                 |> send_req()
                 |> unwrap()

      assert([%{id: id,
                command: "test-bundle:st-echo",
                rule: "when command is test-bundle:st-echo must have test-bundle:st-echo"}] == response)

      rules = Rules.rules_for_command("test-bundle:st-echo")
              |> unwrap()
      assert rules == []
    end

    test "error when dropping rule with non-UUID string id" do
      error = new_req(args: ["delete", "not-a-uuid"])
              |> send_req()
              |> unwrap_error()

      assert(error == ~s(Invalid UUID "not-a-uuid"))
    end

    test "error when dropping rule with unknown id" do
      error = new_req(args: ["delete", @bad_uuid])
              |> send_req()
              |> unwrap_error()

      assert(error == ~s(Rule "#{@bad_uuid}" could not be found))
    end
  end

  #########################################################################

  test "retrieving a rule by ID works" do
    %Rule{id: id} = Rules.ingest("when command is operable:rule allow")
                    |> unwrap()

    payload = new_req(args: ["info", id])
              |> send_req()
              |> unwrap()

    assert %{id: id,
             command_name: "operable:rule",
             rule: "when command is operable:rule allow"} == payload
  end

  test "retrieving a non-existent rule fails" do
    error = new_req(args: ["info", @bad_uuid])
            |> send_req()
            |> unwrap_error()

    assert(error == "Could not find 'rule' with the id '#{@bad_uuid}'")
  end

  test "retrieving a rule requires an ID" do
    error = new_req(args: ["info"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Not enough args. Arguments required: exactly 1.")
  end

  test "the ID given for retrieving a rule must be a string and a UUID" do
    error = new_req(args: ["info", "not_a_uuid"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Invalid UUID \"not_a_uuid\"")

    error = new_req(args: ["info", 123])
            |> send_req()
            |> unwrap_error()
    assert(error == "Argument must be a string")
  end

  test "only one rule can be retrieved at a time" do
    %Rule{id: rule_1_id} = Rules.ingest("when command is operable:rule allow") |> unwrap()
    %Rule{id: rule_2_id} = Rules.ingest("when command is operable:bundle-list allow") |> unwrap()

    error = new_req(args: ["info", rule_1_id, rule_2_id])
            |> send_req()
            |> unwrap_error()

    assert(error == "Too many args. Arguments required: exactly 1.")
  end

  #########################################################################

  test "passing an unknown subcommand fails" do
    error = new_req(args: ["not-a-subcommand"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Unknown subcommand 'not-a-subcommand'")
  end

  #### Helper Functions ####

  defp assert_uuid(maybe_uuid),
    do: assert Cog.UUID.is_uuid?(maybe_uuid)

  #### Setup Functions ####

  defp with_bundle(context) do
    config = %{"name" => "test-bundle",
      "version" => "0.1.0",
      "cog_bundle_version" => 4,
      "permissions" => [
        "test-bundle:st-echo"],
      "commands" => %{
        "st-echo" => %{
          "executable" => "foobar",
          "description" => "test echo",
          "rules" => ["when command is test-bundle:st-echo must have test-bundle:st-echo"]}}}

    bundle = Bundles.install(%{"name" => "test-bundle", "version" => "0.1.0", "config_file" => config})
             |> unwrap()

    # If a test is tagged 'with_disabled_bundle' we don't enable the bundle
    if context[:with_disabled_bundle] == nil do
      Bundles.set_bundle_version_status(bundle, :enabled)
    end

    [bundle: bundle]
  end
end
