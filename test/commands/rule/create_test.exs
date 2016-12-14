defmodule Cog.Test.Commands.Rule.CreateTest do
  use Cog.CommandCase, command_module: Cog.Commands.Rule.Create

  import Cog.Support.ModelUtilities, only: [permission: 1]
  alias Cog.Repository.Bundles

  setup :with_bundle

  test "adding a rule for a command" do
    permission("site:permission")

    response = new_req(args: ["when command is test-bundle:st-echo must have site:permission"])
               |> send_req()
               |> unwrap()

    assert_uuid(response[:id])
    assert(%{command: "test-bundle:st-echo",
             rule: "when command is test-bundle:st-echo must have site:permission"} = response)
  end

  test "error when specifying too many arguments for manual rule creation" do
    error = new_req(args: ["blah", "blah", "blah"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Invalid args. Please pass between 1 and 2 arguments.")
  end

  test "error when creating rule for an unrecognized command" do
    permission("site:permission")

    error = new_req(args: ["not_really:a_command", "site:permission"])
            |> send_req()
            |> unwrap_error()

    assert(error == ~s(Could not create rule: Unrecognized command "not_really:a_command"))
  end

  test "error when creating rule with an unrecognized permission" do
    error = new_req(args: ["test-bundle:st-echo", "site:permission"])
            |> send_req()
            |> unwrap_error()

    assert(error == ~s(Could not create rule: Unrecognized permission "site:permission"))
  end

  test "error when creating a rule specifying a permission from an unacceptable namespace" do
    permission("foo:bar")

    error = new_req(args: ["test-bundle:st-echo", "foo:bar"])
            |> send_req()
            |> unwrap_error()

    assert(error == ~s(Could not create rule with permission outside of command bundle or the \"site\" namespace))
  end

  test "error when manually creating a rule with invalid syntax" do
    error = new_req(args: [ "this is totally not a valid rule"])
            |> send_req()
            |> unwrap_error()

    assert(error == ~s{Could not create rule: \"(Line: 1, Col: 0) syntax error before: \\"this\\".\"})
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
