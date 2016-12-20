defmodule Cog.Test.Commands.Trigger.EnableTest do
  use Cog.CommandCase, command_module: Cog.Commands.Trigger.Enable

  alias Cog.Models.Trigger
  alias Cog.Repository.Triggers

  test "enabling a trigger" do
    {:ok, %Trigger{id: id, enabled: false}} = Triggers.new(%{name: "foo", pipeline: "echo stuff", enabled: false})

    {:ok, payload} = new_req(args: ["foo"])
    |> send_req()

    assert %{id: ^id,
             name: "foo",
             enabled: true} = payload
  end
end
