defmodule Cog.Test.Commands.Bundle.DisableTest do
  use Cog.CommandCase, command_module: Cog.Commands.Bundle

  alias Cog.Commands.Bundle.Disable
  alias Cog.Repository.Bundles
  import Cog.Support.ModelUtilities, only: [bundle_version: 1]

  test "disable a bundle" do
    bundle_version = bundle_version("test_bundle")
    Bundles.set_bundle_version_status(bundle_version, :enabled)

    {:ok, response} = new_req(args: ["test_bundle"])
    |> send_req(Disable)

    assert(response == %{name: "test_bundle", status: "disabled", version: "0.1.0"})
    refute(Bundles.enabled?(bundle_version))
  end
end
