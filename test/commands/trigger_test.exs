defmodule Cog.Test.Commands.TriggerTest do
  use Cog.CommandCase, command_tag: :trigger
  require Logger

  alias Cog.Commands.Trigger.{Create, Delete, Disable, Enable, Info, List, Update}

  alias Cog.Models.Trigger
  alias Cog.Repository.Triggers

  test "creating a trigger (simple)" do
    {:ok, payload} = new_req(args: ["foo", "echo stuff"])
    |> send_req(Create)

    assert %{id: _,
             name: "foo",
             pipeline: "echo stuff",
             enabled: true,
             as_user: nil,
             description: nil,
             invocation_url: _,
             timeout_sec: 30} = payload
  end

  test "creating a trigger (complex)" do
    {:ok, payload} = new_req(args: ["foo", "echo stuff"],
                             options: %{"description" => "behold, a trigger",
                                        "enabled" => false,
                                        "as-user" => "bobby_tables",
                                        "timeout-sec" => 100})
    |> send_req(Create)

    assert %{id: _,
             name: "foo",
             pipeline: "echo stuff",
             enabled: false,
             as_user: "bobby_tables",
             description: "behold, a trigger",
             invocation_url: _,
             timeout_sec: 100} = payload
  end

  test "creating a trigger with an invalid timeout fails" do
    {:error, error} = new_req(args: ["foo", "echo stuff"],
                              options: %{"timeout-sec" => 0})
    |> send_req(Create)

    assert(error == "timeout_sec must be greater than 0")
  end

  test "retrieving details about a trigger" do
    {:ok, %Trigger{id: id}} = Triggers.new(%{name: "foo", pipeline: "echo stuff"})

    {:ok, payload} = new_req(args: ["foo"])
    |> send_req(Info)

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
    |> send_req(Info)

    assert(error == "Could not find 'trigger' with the name 'foo'")
  end

  test "list existing triggers" do
    {:ok, %Trigger{id: foo_id}} = Triggers.new(%{name: "foo", pipeline: "echo stuff"})
    {:ok, %Trigger{id: bar_id}} = Triggers.new(%{name: "bar", pipeline: "echo more stuff"})

    {:ok, results} = new_req()
    |> send_req(List)
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

  test "updating a trigger" do
    {:ok, %Trigger{id: id}} = Triggers.new(%{name: "foo", pipeline: "echo stuff"})
    {:ok, payload} = new_req(args: ["foo"],
                             options: %{"pipeline" => "echo all the things"})
    |> send_req(Update)

    assert %{id: ^id,
             pipeline: "echo all the things"} = payload
  end

  test "enabling a trigger" do
    {:ok, %Trigger{id: id, enabled: false}} = Triggers.new(%{name: "foo", pipeline: "echo stuff", enabled: false})

    {:ok, payload} = new_req(args: ["foo"])
    |> send_req(Enable)

    assert %{id: ^id,
             name: "foo",
             enabled: true} = payload
  end

  test "disabling a trigger" do
    {:ok, %Trigger{id: id, enabled: true}} = Triggers.new(%{name: "foo", pipeline: "echo stuff"})

    {:ok, payload} = new_req(args: ["foo"])
    |> send_req(Disable)

    assert %{id: ^id,
             name: "foo",
             enabled: false} = payload
  end

  test "deleting a trigger by name" do
    {:ok, %Trigger{id: id}} = Triggers.new(%{name: "foo", pipeline: "echo stuff"})

    {:ok, [payload]} = new_req(args: ["foo"])
    |> send_req(Delete)

    assert %{id: ^id,
             name: "foo"} = payload

    refute Cog.Repo.get(Trigger, id)
  end

  test "deleting multiple triggers by name" do
    {:ok, %Trigger{id: foo_id}} = Triggers.new(%{name: "foo", pipeline: "echo stuff"})
    {:ok, %Trigger{id: bar_id}} = Triggers.new(%{name: "bar", pipeline: "echo stuff"})
    {:ok, %Trigger{id: baz_id}} = Triggers.new(%{name: "baz", pipeline: "echo stuff"})

    {:ok, payload} = new_req(args: ["foo", "bar", "baz"])
    |> send_req(Delete)
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
