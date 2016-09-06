defmodule Integration.Commands.UserTest do
  use Cog.AdapterCase, adapter: "test"

  setup do
    user = user("tester")
    |> with_chat_handle_for("test")
    |> with_permission("operable:manage_users")

    {:ok, %{user: user}}
  end

  test "listing users", %{user: user} do
    payload = user
    |> send_message("@bot: operable:user list")
    |> Enum.sort_by(fn(b) -> b[:username] end)

    assert [%{username: "admin"},
            %{username: "tester"}] = payload
  end

  test "information about a specific user", %{user: user} do
    [payload] = user
    |> send_message("@bot: operable:user info admin")

    assert %{username: "admin"} = payload
  end

  test "information about a missing user fails", %{user: user} do
    response = send_message(user, "@bot: operable:user info not-a-real-user")
    assert_error_message_contains(response, "Could not find 'user' with the name 'not-a-real-user'")
  end

  test "not providing the user to get information about fails", %{user: user} do
    response = send_message(user, "@bot: operable:user info")
    assert_error_message_contains(response, "Not enough args. Arguments required: exactly 1.")
  end

  test "providing multiple users to get information about fails", %{user: user} do
    response = send_message(user, "@bot: operable:user info admin tester")
    assert_error_message_contains(response, "Too many args. Arguments required: exactly 1.")
  end

  test "attaching a chat handle to a user works", %{user: user} do
    user("dummy")

    [payload] = user
    |> send_message("@bot: operable:user attach-handle dummy dummy-handle")

    assert %{chat_provider: %{name: "test"},
             handle: "dummy-handle",
             id: _,
             username: "dummy"} = payload
  end

  test "attaching a chat handle to a non-existent user fails", %{user: user} do
    response = send_message(user, "@bot: operable:user attach-handle not-a-user test-handle")
    assert_error_message_contains(response, "Could not find 'user' with the name 'not-a-user'")
  end

  test "attaching a chat handle without specifying a chat handle fails", %{user: user} do
    response = send_message(user, "@bot: operable:user attach-handle dummy")
    assert_error_message_contains(response, "Not enough args. Arguments required: exactly 2")
  end

  test "attaching a chat handle without specifying a user or chat handle fails", %{user: user} do
    response = send_message(user, "@bot: operable:user attach-handle")
    assert_error_message_contains(response, "Not enough args. Arguments required: exactly 2")
  end

  test "detaching a chat handle works", %{user: user} do
    user("dummy")
    |> with_chat_handle_for("test")

    [payload] = user
    |> send_message("@bot: operable:user detach-handle dummy")

    assert %{chat_provider: %{name: "test"},
             username: "dummy"} = payload
  end

  test "detaching a chat handle works even if there wasn't a handle to begin with", %{user: user} do
    user("dummy")

    [payload] = user
    |> send_message("@bot: operable:user detach-handle dummy")

    assert %{chat_provider: %{name: "test"},
             username: "dummy"} = payload
  end

  test "detaching a chat handle from a non-existent user fails", %{user: user} do
    response = send_message(user, "@bot: operable:user detach-handle not-a-user")
    assert_error_message_contains(response, "Could not find 'user' with the name 'not-a-user'")
  end

  test "detaching a chat handle without specifying a user fails", %{user: user} do
    response = send_message(user, "@bot: operable:user detach-handle")
    assert_error_message_contains(response, "Not enough args. Arguments required: exactly 1")
  end

  test "listing chat handles works", %{user: user} do
    user("dummy")
    |> with_chat_handle_for("test")

    payload = user
    |> send_message("@bot: operable:user list-handles")
    |> Enum.sort_by(fn(h) -> h[:username] end)

    assert [%{username: "dummy",
              handle: "dummy"},
            %{username: "tester",
              handle: "tester"}] = payload
  end

  test "passing an unknown subcommand fails", %{user: user} do
    response = send_message(user, "@bot: operable:user not-a-subcommand")
    assert_error_message_contains(response, "Whoops! An error occurred. Unknown subcommand 'not-a-subcommand'")
  end

end
