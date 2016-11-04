defmodule Cog.Test.Commands.EchoTest do
  use Cog.CommandCase, command_module: Cog.Commands.Echo

  test "Repeats whatever it is passed" do
    {:ok, response} = new_req(args: ["this", "is", "nifty"])
    |> send_req()

    assert(response == "this is nifty")
  end

  test "serializes json when it's passed" do
    {:ok, response} = new_req(args: [%{"bar" => "baz"}])
    |> send_req()

    assert(Poison.decode!(response) == %{"bar" => "baz"})
  end
end
