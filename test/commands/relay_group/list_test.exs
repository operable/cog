defmodule Cog.Test.Commands.RelayGroup.ListTest do
  use Cog.CommandCase, command_module: Cog.Commands.RelayGroup

  import Cog.Support.ModelUtilities, only: [relay_group: 1]
  alias Cog.Commands.RelayGroup.List

  test "listing relay groups work" do
    relay_group("relay_group1")
    relay_group("relay_group2")

    response = new_req(args: [])
               |> send_req(List)
               |> unwrap()

    assert([%{name: "relay_group1"},
            %{name: "relay_group2"}] = response)
  end

  test "listing with no relay groups returns an empty list" do
    payload = new_req(args: [])
              |> send_req(List)
              |> unwrap()

    assert([] == payload)
  end
end
