defmodule Cog.Commands.BundleTest do
  use Cog.EmbeddedCommandCase

  alias Cog.Repository.Bundles
  alias Cog.Support.ModelUtilities

  setup do
    bundle_version = ModelUtilities.bundle_version("test_bundle")
    {:ok, %{bundle_version: bundle_version}}
  end

  # TODO: NEEDS DATABASE
  # test "listing bundles", %{user: user} do
  #   {:ok, result} = execute_embedded_command("bundle", args: ["list"])

  #   sorted = Enum.sort_by(result.body, fn(b) -> b[:name] end)

  #   assert [%{name: "operable"},
  #           %{name: "test_bundle"}] =sorted
  # end

  # test "information about a single bundle", %{user: user} do
  #   [payload] = user
  #   |> send_message("@bot: operable:bundle info operable")
  #   |> decode_payload

  #   version = Application.fetch_env!(:cog, :embedded_bundle_version)

  #   assert %{name: "operable",
  #            enabled_version: %{version: ^version}} = payload
  # end

  # test "list versions for a bundle", %{user: user} do
  #   payload = user
  #   |> send_message("@bot: operable:bundle versions operable")
  #   |> decode_payload

  #   version = Application.fetch_env!(:cog, :embedded_bundle_version)

  #   assert [%{name: "operable",
  #             version: ^version}] = payload
  # end

  # test "enable a bundle", %{user: user, bundle_version: bundle_version} do
  #   response = send_message(user, "@bot: bundle enable test_bundle")
  #   assert_payload(response, %{name: "test_bundle", status: "enabled", version: "0.1.0"})
  #   assert Bundles.enabled?(bundle_version)
  # end

  # test "disable a bundle", %{user: user, bundle_version: bundle_version} do
  #   Bundles.set_bundle_version_status(bundle_version, :enabled)

  #   response = send_message(user, "@bot: bundle disable test_bundle")
  #   assert_payload(response, %{name: "test_bundle", status: "disabled", version: "0.1.0"})
  #   refute Bundles.enabled?(bundle_version)
  # end

  # test "passing an unknown subcommand fails", %{user: user} do
  #   response = send_message(user, "@bot: operable:bundle not-a-subcommand")
  #   assert_error_message_contains(response, "Whoops! An error occurred. Unknown subcommand 'not-a-subcommand'")
  # end

end
