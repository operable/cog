defmodule Cog.Test.Commands.Trigger.UpdateTest do
  use Cog.CommandCase, command_module: Cog.Commands.Trigger.Update

  alias Cog.Models.Trigger
  alias Cog.Repository.Triggers

  test "updating a trigger" do
    {:ok, %Trigger{id: id}} = Triggers.new(%{name: "foo", pipeline: "echo stuff"})
    {:ok, payload} = new_req(args: ["foo"],
                             options: %{"pipeline" => "echo all the things"})
    |> send_req()

    assert %{id: ^id,
             pipeline: "echo all the things"} = payload
  end
end
