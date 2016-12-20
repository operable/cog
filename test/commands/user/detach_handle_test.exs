defmodule Cog.Test.Commands.User.DetachHandleTest do
  use Cog.CommandCase, command_module: Cog.Commands.User.DetachHandle

  import Cog.Support.ModelUtilities, only: [user: 1,
                                            with_chat_handle_for: 2]

  setup :with_users

  test "detaching a chat handle works" do
    user("dummy")
    |> with_chat_handle_for("test")

    payload = new_req(args: ["dummy"])
              |> send_req()
              |> unwrap()

    assert %{chat_provider: %{name: "test"},
             username: "dummy"} = payload
  end

  test "detaching a chat handle works even if there wasn't a handle to begin with" do
    user("dummy")

    payload = new_req(args: ["dummy"])
              |> send_req()
              |> unwrap()

    assert %{chat_provider: %{name: "test"},
             username: "dummy"} = payload
  end

  test "detaching a chat handle from a non-existent user fails" do
    error = new_req(args: ["not-a-user"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Could not find 'user' with the name 'not-a-user'")
  end

  test "detaching a chat handle without specifying a user fails" do
    error = new_req()
            |> send_req()
            |> unwrap_error()

    assert(error == "Not enough args. Arguments required: exactly 1.")
  end


  #### Setup Functions ####

  defp with_users(_) do
    [users: [user("admin"), user("tester")]]
  end
end



