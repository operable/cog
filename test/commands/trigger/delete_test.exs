defmodule Cog.Test.Commands.Trigger.DeleteTest do
  use Cog.CommandCase, command_module: Cog.Commands.Trigger.Delete

  alias Cog.Models.Trigger
  alias Cog.Repository.Triggers

  test "deleting a trigger by name" do
    {:ok, %Trigger{id: id}} = Triggers.new(%{name: "foo", pipeline: "echo stuff"})

    {:ok, [payload]} = new_req(args: ["foo"])
    |> send_req()

    assert %{id: ^id,
             name: "foo"} = payload

    refute Cog.Repo.get(Trigger, id)
  end

  test "deleting multiple triggers by name" do
    {:ok, %Trigger{id: foo_id}} = Triggers.new(%{name: "foo", pipeline: "echo stuff"})
    {:ok, %Trigger{id: bar_id}} = Triggers.new(%{name: "bar", pipeline: "echo stuff"})
    {:ok, %Trigger{id: baz_id}} = Triggers.new(%{name: "baz", pipeline: "echo stuff"})

    {:ok, payload} = new_req(args: ["foo", "bar", "baz"])
    |> send_req()
    payload = Enum.sort_by(payload, fn(m) -> m[:name] end)

    assert [%{id: ^bar_id,
              name: "bar"},
            %{id: ^baz_id,
              name: "baz"},
            %{id: ^foo_id,
              name: "foo"}]= payload

    for id <- [foo_id, bar_id, baz_id],
      do: refute Cog.Repo.get(Trigger, id)
  end
end
