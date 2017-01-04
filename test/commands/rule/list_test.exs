defmodule Cog.Test.Commands.Rule.ListTest do
  use Cog.CommandCase, command_module: Cog.Commands.Rule.List

  alias Cog.Repository.Bundles

  setup :with_bundle

  test "listing rules" do
    response = new_req(args: ["test-bundle:st-echo"])
               |> send_req()
               |> unwrap()

    assert([%{command: "test-bundle:st-echo",
              rule: "when command is test-bundle:st-echo must have test-bundle:st-echo"}] = response)
  end

  test "error when listing rules for an unrecognized command" do
    error = new_req(args: ["not_really:a_command"])
            |> send_req()
            |> unwrap_error()

    assert(error == ~s(Command "not_really:a_command" could not be found))
  end

  @tag :with_disabled_bundle
  test "listing rules for a disabled command fails" do
    error = new_req(args: ["test-bundle:st-echo"])
            |> send_req()
            |> unwrap_error()

    assert(error == ~s(test-bundle:st-echo is not enabled. Enable a bundle version and try again))
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
