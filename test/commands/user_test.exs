defmodule Cog.Test.Commands.UserTest do
  use Cog.CommandCase, command_module: Cog.Commands.User

  import Cog.Support.ModelUtilities, only: [user: 1,
                                            with_chat_handle_for: 2]

  setup :with_users

  test "listing users" do
    payload = new_req(args: ["list"])
              |> send_req()
              |> unwrap()
              |> Enum.sort_by(fn(b) -> b[:username] end)

    assert [%{username: "admin"},
            %{username: "tester"}] = payload
  end

  test "information about a specific user" do
    payload = new_req(args: ["info", "admin"])
              |> send_req()
              |> unwrap()

    assert %{username: "admin"} = payload
  end

  test "information about a missing user fails" do
    error = new_req(args: ["info", "not-a-real-user"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Could not find 'user' with the name 'not-a-real-user'")
  end

  test "not providing the user to get information about fails" do
    error = new_req(args: ["info"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Not enough args. Arguments required: exactly 1.")
  end

  test "providing multiple users to get information about fails" do
    error = new_req(args: ["info", "admin", "tester"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Too many args. Arguments required: exactly 1.")
  end

  test "attaching a chat handle to a user works" do
    user("dummy")

    payload = new_req(args: ["attach-handle", "dummy", "dummy-handle"])
              |> send_req()
              |> unwrap()

    assert %{chat_provider: %{name: "test"},
             handle: "dummy-handle",
             id: _,
             username: "dummy"} = payload
  end

  test "attaching a chat handle to a non-existent user fails" do
    error = new_req(args: ["attach-handle", "not-a-user", "test-handle"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Could not find 'user' with the name 'not-a-user'")
  end

  test "attaching a chat handle without specifying a chat handle fails" do
    error = new_req(args: ["attach-handle", "dummy"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Not enough args. Arguments required: exactly 2.")
  end

  test "attaching a chat handle without specifying a user or chat handle fails" do
    error = new_req(args: ["attach-handle"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Not enough args. Arguments required: exactly 2.")
  end

  test "detaching a chat handle works" do
    user("dummy")
    |> with_chat_handle_for("test")

    payload = new_req(args: ["detach-handle", "dummy"])
              |> send_req()
              |> unwrap()

    assert %{chat_provider: %{name: "test"},
             username: "dummy"} = payload
  end

  test "detaching a chat handle works even if there wasn't a handle to begin with" do
    user("dummy")

    payload = new_req(args: ["detach-handle", "dummy"])
              |> send_req()
              |> unwrap()

    assert %{chat_provider: %{name: "test"},
             username: "dummy"} = payload
  end

  test "detaching a chat handle from a non-existent user fails" do
    error = new_req(args: ["detach-handle", "not-a-user"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Could not find 'user' with the name 'not-a-user'")
  end

  test "detaching a chat handle without specifying a user fails" do
    error = new_req(args: ["detach-handle"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Not enough args. Arguments required: exactly 1.")
  end

  test "listing chat handles works", %{users: users} do
    Enum.each(users, &(with_chat_handle_for(&1, "test")))

    payload = new_req(args: ["list-handles"])
              |> send_req()
              |> unwrap()
              |> Enum.sort_by(fn(h) -> h[:username] end)

    assert [%{username: "admin",
              handle: "admin"},
            %{username: "tester",
              handle: "tester"}] = payload
  end

  test "passing an unknown subcommand fails" do
    error = new_req(args: ["not-a-subcommand"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Unknown subcommand 'not-a-subcommand'")
  end


  #### Setup Functions ####

  defp with_users(_) do
    [users: [user("admin"), user("tester")]]
  end
end
