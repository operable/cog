defmodule Cog.Test.Commands.Bundle.ListTest do
  use Cog.CommandCase, command_module: Cog.Commands.Bundle

  alias Cog.Commands.Bundle.List
  import Cog.Support.ModelUtilities, only: [bundle_version: 1]

  test "listing bundles" do
    bundle_version("test_bundle")

    {:ok, response} = new_req(args: [])
    |> send_req(List)

    bundles = Enum.map(response, &Map.take(&1, [:name]))
    |> Enum.sort

    assert([%{name: "operable"},
            %{name: "test_bundle"}] == bundles)
  end
end
