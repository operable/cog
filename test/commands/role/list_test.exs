defmodule Cog.Test.Commands.Role.ListTest do
  use Cog.CommandCase, command_module: Cog.Commands.Role.List

  import Cog.Support.ModelUtilities, only: [role: 1]
  alias Cog.Commands.Role.List

  test "listing roles works" do
    role("admin")
    role("cog-admin")
    payload = new_req(args: [])
              |> send_req(List)
              |> unwrap()
              |> Enum.sort_by(&(&1[:name]))

    assert [%{name: "admin"},
            %{name: "cog-admin"}] = payload
  end
end
