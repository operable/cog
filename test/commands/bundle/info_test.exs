defmodule Cog.Test.Commands.Bundle.InfoTest do
  use Cog.CommandCase, command_module: Cog.Commands.Bundle

  alias Cog.Commands.Bundle.Info

  test "information about a single bundle" do
    {:ok, response} = new_req(args: ["operable"])
    |> send_req(Info)

    version = Application.fetch_env!(:cog, :embedded_bundle_version)

    assert(%{name: "operable",
             enabled_version: %{version: ^version}} = response)
  end
end
