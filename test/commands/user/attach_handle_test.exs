defmodule Cog.Test.Commands.User.AttachHandleTest do
  use Cog.CommandCase, command_module: Cog.Commands.User.AttachHandle

  import Cog.Support.ModelUtilities, only: [user: 1]

  setup :with_users

  test "attaching a chat handle to a user works" do
    user("dummy")

    payload = new_req(args: ["dummy", "dummy-handle"])
              |> send_req()
              |> unwrap()

    assert %{chat_provider: %{name: "test"},
             handle: "dummy-handle",
             id: _,
             username: "dummy"} = payload
  end

  test "attaching a chat handle to a non-existent user fails" do
    error = new_req(args: ["not-a-user", "test-handle"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Could not find 'user' with the name 'not-a-user'")
  end

  test "attaching a chat handle without specifying a chat handle fails" do
    error = new_req(args: ["dummy"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Not enough args. Arguments required: exactly 2.")
  end

  test "attaching a chat handle without specifying a user or chat handle fails" do
    error = new_req()
            |> send_req()
            |> unwrap_error()

    assert(error == "Not enough args. Arguments required: exactly 2.")
  end


  #### Setup Functions ####

  defp with_users(_) do
    [users: [user("admin"), user("tester")]]
  end
end


