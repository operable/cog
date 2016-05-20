defmodule Integration.Commands.BundleTest do
  use Cog.AdapterCase, adapter: "test"
  alias Cog.Support.ModelUtilities
  alias Cog.Models.Bundle
  alias Cog.Repo

  setup do
    user = user("vanstee", first_name: "Patrick", last_name: "Van Stee")
    |> with_chat_handle_for("test")
    |> with_permission("operable:manage_commands")

    {:ok, %{user: user}}
  end

  @tag :skip
  test "checking bundle status", %{user: user} do
    ModelUtilities.bundle_version("test_bundle")

    response = send_message(user, "@bot: operable:bundle status test_bundle")

    [bundle_status] = decode_payload(response)

    assert bundle_status.bundle == "test_bundle"
    assert bundle_status.status == "disabled"
  end

  @tag :skip
  test "enable a bundle", %{user: user} do
    bundle = ModelUtilities.bundle_version("test_bundle").bundle

    # First enable the bundle and check the response
    response = send_message(user, "@bot: operable:bundle enable test_bundle")

    [bundle_status] = decode_payload(response)

    assert bundle_status.bundle == "test_bundle"
    assert bundle_status.status == "enabled"

    # Confirm that we enabled the bundle
    updated_bundle = Repo.get(Bundle, bundle.id)

    assert updated_bundle.enabled == true
  end

  @tag :skip
  test "disable a bundle", %{user: user} do
    # Create an enabled bundle
    bundle = ModelUtilities.bundle_version("test_bundle", enabled: true).bundle

    # First disable the bundle
    response = send_message(user, "@bot: operable:bundle disable test_bundle")

    [bundle_status] = decode_payload(response)

    assert bundle_status.bundle == "test_bundle"
    assert bundle_status.status == "disabled"

    # Confirm that we disabled the bundle
    updated_bundle = Repo.get(Bundle, bundle.id)

    assert updated_bundle.enabled == false
  end
end
