defmodule Cog.Test.Commands.User.ListHandlesTest do
  use Cog.CommandCase, command_module: Cog.Commands.User.ListHandles

  import Cog.Support.ModelUtilities, only: [user: 1,
                                            with_chat_handle_for: 2]

  setup :with_users

  test "listing chat handles works", %{users: users} do
    Enum.each(users, &(with_chat_handle_for(&1, "test")))

    payload = new_req()
              |> send_req()
              |> unwrap()
              |> Enum.sort_by(fn(h) -> h[:username] end)

    assert [%{username: "admin",
              handle: "admin"},
            %{username: "tester",
              handle: "tester"}] = payload
  end

  #### Setup Functions ####

  defp with_users(_) do
    [users: [user("admin"), user("tester")]]
  end
end




