defmodule Cog.Test.Commands.Trigger.ListTest do
  use Cog.CommandCase, command_module: Cog.Commands.Trigger.List

  alias Cog.Models.Trigger
  alias Cog.Repository.Triggers

  test "list existing triggers" do
    {:ok, %Trigger{id: foo_id}} = Triggers.new(%{name: "foo", pipeline: "echo stuff"})
    {:ok, %Trigger{id: bar_id}} = Triggers.new(%{name: "bar", pipeline: "echo more stuff"})

    {:ok, results} = new_req()
    |> send_req()
    results = Enum.sort_by(results, fn(m) -> m[:name] end)

    assert [%{id: ^bar_id,
              name: "bar",
              pipeline: "echo more stuff",
              enabled: true,
              as_user: nil,
              description: nil,
              invocation_url: _,
              timeout_sec: 30},
            %{id: ^foo_id,
              name: "foo",
              pipeline: "echo stuff",
              enabled: true,
              as_user: nil,
              description: nil,
              invocation_url: _,
              timeout_sec: 30}] = results
  end
end
