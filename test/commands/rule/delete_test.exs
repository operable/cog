defmodule Cog.Test.Commands.Rule.DeleteTest do
  use Cog.CommandCase, command_module: Cog.Commands.Rule.Delete

  alias Cog.Repository.Bundles
  alias Cog.Repository.Rules

  @bad_uuid "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"

  setup :with_bundle

  test "dropping a rule via a rule id" do
    # Get an ID we can use to drop
    [%{id: id}] = Rules.rules_for_command("test-bundle:st-echo")
                  |> unwrap()

    response = new_req(args: [id])
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
    error = new_req(args: ["not-a-uuid"])
            |> send_req()
            |> unwrap_error()

    assert(error == ~s(Invalid UUID "not-a-uuid"))
  end

  test "error when dropping rule with unknown id" do
    error = new_req(args: [@bad_uuid])
            |> send_req()
            |> unwrap_error()

    assert(error == ~s(Rule "#{@bad_uuid}" could not be found))
  end

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
