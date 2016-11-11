defmodule Cog.Test.Commands.EchoTest do
  use Cog.CommandCase, command_module: Cog.Commands.Echo

  test "Repeats whatever it is passed" do
    response = new_req(args: ["this", "is", "nifty"])
               |> send_req()
               |> unwrap()

    assert(response == "this is nifty")
  end

  test "serializes json when it's passed" do
    response = new_req(args: [%{"bar" => "baz"}])
               |> send_req()
               |> unwrap()

    assert(Poison.decode!(response) == %{"bar" => "baz"})
  end
end
