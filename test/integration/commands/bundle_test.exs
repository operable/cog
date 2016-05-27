defmodule Integration.Commands.BundleTest do
  use Cog.AdapterCase, adapter: "test"
  alias Cog.Repository.Bundles
  alias Cog.Support.ModelUtilities

  setup do
    user = user("vanstee", first_name: "Patrick", last_name: "Van Stee")
    |> with_chat_handle_for("test")
    |> with_permission("operable:manage_commands")

    bundle_version = ModelUtilities.bundle_version("test_bundle")

    {:ok, %{user: user, bundle_version: bundle_version}}
  end

  test "checking bundle status", %{user: user} do
    response = send_message(user, "@bot: bundle status test_bundle")
    assert_payload(response, %{name: "test_bundle", status: "disabled", version: "0.1.0"})
  end

  test "enable a bundle", %{user: user, bundle_version: bundle_version} do
    response = send_message(user, "@bot: bundle enable test_bundle")
    assert_payload(response, %{name: "test_bundle", status: "enabled", version: "0.1.0"})
    assert Bundles.enabled?(bundle_version)
  end

  test "disable a bundle", %{user: user, bundle_version: bundle_version} do
    Bundles.set_bundle_version_status(bundle_version, :enabled)

    response = send_message(user, "@bot: bundle disable test_bundle")
    assert_payload(response, %{name: "test_bundle", status: "disabled", version: "0.1.0"})
    refute Bundles.enabled?(bundle_version)
  end
end
