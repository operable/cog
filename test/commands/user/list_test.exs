defmodule Cog.Test.Commands.User.ListTest do
  use Cog.CommandCase, command_module: Cog.Commands.User.List

  import Cog.Support.ModelUtilities, only: [user: 1]

  test "listing users" do
    user("admin")
    user("tester")

    payload = new_req()
              |> send_req()
              |> unwrap()
              |> Enum.sort_by(fn(b) -> b[:username] end)

    assert [%{username: "admin"},
            %{username: "tester"}] = payload
  end

end
