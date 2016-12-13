defmodule Cog.Test.Commands.Bundle.EnableTest do
  use Cog.CommandCase, command_module: Cog.Commands.Bundle

  alias Cog.Commands.Bundle.Enable
  alias Cog.Repository.Bundles
  import Cog.Support.ModelUtilities, only: [bundle_version: 1]

  test "enable a bundle" do
    bundle_version = bundle_version("test_bundle")

    {:ok, response} = new_req(args: ["test_bundle"])
    |> send_req(Enable)

    assert(response == %{name: "test_bundle", status: "enabled", version: "0.1.0"})
    assert(Bundles.enabled?(bundle_version))
  end
end
