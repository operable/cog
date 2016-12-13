defmodule Cog.Test.Commands.User.InfoTest do
  use Cog.CommandCase, command_module: Cog.Commands.User.Info

  import Cog.Support.ModelUtilities, only: [user: 1]

  setup :with_users

  test "information about a specific user" do
    payload = new_req(args: ["admin"])
              |> send_req()
              |> unwrap()

    assert %{username: "admin"} = payload
  end

  test "information about a missing user fails" do
    error = new_req(args: ["not-a-real-user"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Could not find 'user' with the name 'not-a-real-user'")
  end

  test "not providing the user to get information about fails" do
    error = new_req()
            |> send_req()
            |> unwrap_error()

    assert(error == "Not enough args. Arguments required: exactly 1.")
  end

  test "providing multiple users to get information about fails" do
    error = new_req(args: ["admin", "tester"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Too many args. Arguments required: exactly 1.")
  end

  #### Setup Functions ####

  defp with_users(_) do
    [users: [user("admin"), user("tester")]]
  end
end

