defmodule Cog.Test.Commands.Trigger.DisableTest do
  use Cog.CommandCase, command_module: Cog.Commands.Trigger.Disable

  alias Cog.Models.Trigger
  alias Cog.Repository.Triggers

  test "disabling a trigger" do
    {:ok, %Trigger{id: id, enabled: true}} = Triggers.new(%{name: "foo", pipeline: "echo stuff"})

    {:ok, payload} = new_req(args: ["foo"])
    |> send_req()

    assert %{id: ^id,
             name: "foo",
             enabled: false} = payload
  end
end
