defmodule Cog.Test.Commands.Group.ListTest do
  use Cog.CommandCase, command_module: Cog.Commands.Group

  alias Cog.Commands.Group.List
  import Cog.Support.ModelUtilities, only: [group: 1]

  test "can be listed" do
    Enum.each(1..3, &group("group#{&1}"))

    {:ok, response} = new_req(args: [])
    |> send_req(List)

    response = Enum.sort_by(response, &(&1.name))

    assert([%{name: "group1"},
            %{name: "group2"},
            %{name: "group3"}] = response)
  end
end
