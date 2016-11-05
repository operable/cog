defmodule Cog.Test.Commands.TriggerTest do
  use Cog.CommandCase, command_module: Cog.Commands.Trigger
  require Logger

  alias Cog.Models.Trigger
  alias Cog.Repository.Triggers

  test "creating a trigger (simple)" do
    {:ok, payload} = new_req(args: ["create", "foo", "echo stuff"])
    |> send_req()

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
    {:ok, payload} = new_req(args: ["create", "foo", "echo stuff"],
                             options: %{"description" => "behold, a trigger",
                                        "enabled" => false,
                                        "as-user" => "bobby_tables",
                                        "timeout-sec" => 100})
    |> send_req()

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
    {:error, error} = new_req(args: ["create", "foo", "echo stuff"],
                              options: %{"timeout-sec" => 0})
    |> send_req()

    assert(error == "timeout_sec must be greater than 0")
  end

  test "retrieving details about a trigger" do
    {:ok, %Trigger{id: id}} = Triggers.new(%{name: "foo", pipeline: "echo stuff"})

    {:ok, payload} = new_req(args: ["info", "foo"])
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
    {:error, error} = new_req(args: ["info", "foo"])
    |> send_req()

    assert(error == "Could not find 'trigger' with the name 'foo'")
  end

  test "list existing triggers" do
    {:ok, %Trigger{id: foo_id}} = Triggers.new(%{name: "foo", pipeline: "echo stuff"})
    {:ok, %Trigger{id: bar_id}} = Triggers.new(%{name: "bar", pipeline: "echo more stuff"})

    {:ok, results} = new_req(args: ["list"])
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

  test "listing is the default operation" do
    {:ok, %Trigger{id: foo_id}} = Triggers.new(%{name: "foo", pipeline: "echo stuff"})
    {:ok, %Trigger{id: bar_id}} = Triggers.new(%{name: "bar", pipeline: "echo more stuff"})

    {:ok, results} = new_req()
    |> send_req()
    results = Enum.sort_by(results, fn(m) -> m[:name] end)

    assert  [%{id: ^bar_id,
               name: "bar"},
             %{id: ^foo_id,
               name: "foo"}] = results
  end

  test "updating a trigger" do
    {:ok, %Trigger{id: id}} = Triggers.new(%{name: "foo", pipeline: "echo stuff"})
    {:ok, payload} = new_req(args: ["update", "foo"],
                             options: %{"pipeline" => "echo all the things"})
    |> send_req()

    assert %{id: ^id,
             pipeline: "echo all the things"} = payload
  end

  test "enabling a trigger" do
    {:ok, %Trigger{id: id, enabled: false}} = Triggers.new(%{name: "foo", pipeline: "echo stuff", enabled: false})

    {:ok, payload} = new_req(args: ["enable", "foo"])
    |> send_req()

    assert %{id: ^id,
             name: "foo",
             enabled: true} = payload
  end

  test "disabling a trigger" do
    {:ok, %Trigger{id: id, enabled: true}} = Triggers.new(%{name: "foo", pipeline: "echo stuff"})

    {:ok, payload} = new_req(args: ["disable", "foo"])
    |> send_req()

    assert %{id: ^id,
             name: "foo",
             enabled: false} = payload
  end

  test "deleting a trigger by name" do
    {:ok, %Trigger{id: id}} = Triggers.new(%{name: "foo", pipeline: "echo stuff"})

    {:ok, [payload]} = new_req(args: ["delete", "foo"])
    |> send_req()

    assert %{id: ^id,
             name: "foo"} = payload

    refute Cog.Repo.get(Trigger, id)
  end

  test "deleting multiple triggers by name" do
    {:ok, %Trigger{id: foo_id}} = Triggers.new(%{name: "foo", pipeline: "echo stuff"})
    {:ok, %Trigger{id: bar_id}} = Triggers.new(%{name: "bar", pipeline: "echo stuff"})
    {:ok, %Trigger{id: baz_id}} = Triggers.new(%{name: "baz", pipeline: "echo stuff"})

    {:ok, payload} = new_req(args: ["delete", "foo", "bar", "baz"])
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

  test "passing an unknown subcommand fails" do
    {:error, error} = new_req(args: ["not-a-subcommand"])
    |> send_req()

    assert(error == "Unknown subcommand 'not-a-subcommand'")
  end

end
