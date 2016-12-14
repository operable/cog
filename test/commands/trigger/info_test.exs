defmodule Cog.Test.Commands.Trigger.InfoTest do
  use Cog.CommandCase, command_module: Cog.Commands.Trigger.Info

  alias Cog.Models.Trigger
  alias Cog.Repository.Triggers

  test "retrieving details about a trigger" do
    {:ok, %Trigger{id: id}} = Triggers.new(%{name: "foo", pipeline: "echo stuff"})

    {:ok, payload} = new_req(args: ["foo"])
    |> send_req()

    assert %{id: ^id,
             name: "foo",
             pipeline: "echo stuff",
             enabled: true,
             as_user: nil,
             description: nil,
             invocation_url: _,
             timeout_sec: 30} = payload
  end

  test "retrieving details about a non-existent trigger fails" do
    {:error, error} = new_req(args: ["foo"])
    |> send_req()

    assert(error == "Could not find 'trigger' with the name 'foo'")
  end
end
