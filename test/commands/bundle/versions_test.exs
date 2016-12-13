defmodule Cog.Test.Commands.Bundle.VersionsTest do
  use Cog.CommandCase, command_module: Cog.Commands.Bundle

  alias Cog.Commands.Bundle.Versions

  test "list versions for a bundle" do
    {:ok, response} = new_req(args: ["operable"])
    |> send_req(Versions)

    version = Application.fetch_env!(:cog, :embedded_bundle_version)

    assert([%{name: "operable",
              version: ^version}] = response)
  end
end
