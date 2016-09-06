defmodule Integration.Commands.TriggerTest do
  use Cog.AdapterCase, adapter: "test"
  require Logger

  alias Cog.Models.Trigger
  alias Cog.Repository.Triggers

  setup do
    user = user("cog")
    |> with_chat_handle_for("test")
    |> with_permission("operable:manage_triggers")
    {:ok, %{user: user}}
  end

  test "creating a trigger (simple)", %{user: user} do
    [payload] = user
    |> send_message("@bot: operable:trigger create foo 'echo stuff'")

    assert %{id: _,
             name: "foo",
             pipeline: "echo stuff",
             enabled: true,
             as_user: nil,
             description: nil,
             invocation_url: _,
             timeout_sec: 30} = payload
  end

  test "creating a trigger (complex)", %{user: user} do
    [payload] = user
    |> send_message("@bot: operable:trigger create foo 'echo stuff' --description='behold, a trigger' --enabled=false --as-user=bobby_tables --timeout-sec=100")

    assert %{id: _,
             name: "foo",
             pipeline: "echo stuff",
             enabled: false,
             as_user: "bobby_tables",
             description: "behold, a trigger",
             invocation_url: _,
             timeout_sec: 100} = payload
  end

  test "creating a trigger with an invalid timeout fails", %{user: user} do
    response = send_message(user, "@bot: operable:trigger create foo 'echo stuff' --timeout-sec=0")
    assert_error_message_contains(response, "timeout_sec must be greater than 0")
  end

  test "retrieving details about a trigger", %{user: user} do
    {:ok, %Trigger{id: id}} = Triggers.new(%{name: "foo", pipeline: "echo stuff"})
    [payload] = user
    |> send_message("@bot: operable:trigger info foo")

    assert %{id: ^id,
             name: "foo",
             pipeline: "echo stuff",
             enabled: true,
             as_user: nil,
             description: nil,
             invocation_url: _,
             timeout_sec: 30} = payload
  end

  test "retrieving details about a non-existent trigger fails", %{user: user} do
    response = send_message(user, "@bot: operable:trigger info foo")
    assert_error_message_contains(response, "Could not find 'trigger' with the name 'foo'")
  end

  test "list existing triggers", %{user: user} do
    {:ok, %Trigger{id: foo_id}} = Triggers.new(%{name: "foo", pipeline: "echo stuff"})
    {:ok, %Trigger{id: bar_id}} = Triggers.new(%{name: "bar", pipeline: "echo more stuff"})
    results = user
    |> send_message("@bot: operable:trigger list")
    |> Enum.sort_by(fn(m) -> m[:name] end)

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

  test "listing is the default operation", %{user: user} do
    {:ok, %Trigger{id: foo_id}} = Triggers.new(%{name: "foo", pipeline: "echo stuff"})
    {:ok, %Trigger{id: bar_id}} = Triggers.new(%{name: "bar", pipeline: "echo more stuff"})
    results = user
    |> send_message("@bot: operable:trigger")
    |> Enum.sort_by(fn(m) -> m[:name] end)

    assert  [%{id: ^bar_id,
               name: "bar"},
             %{id: ^foo_id,
               name: "foo"}] = results
  end

  test "updating a trigger", %{user: user} do
    {:ok, %Trigger{id: id}} = Triggers.new(%{name: "foo", pipeline: "echo stuff"})
    [payload] = user
    |> send_message("@bot: operable:trigger update foo --pipeline='echo all the things'")

    assert %{id: ^id,
             pipeline: "echo all the things"} = payload
  end

  test "enabling a trigger", %{user: user} do
    {:ok, %Trigger{id: id, enabled: false}} = Triggers.new(%{name: "foo", pipeline: "echo stuff", enabled: false})
    [payload] = user
    |> send_message("@bot: operable:trigger enable foo")

    assert %{id: ^id,
             name: "foo",
             enabled: true} = payload
  end

  test "disabling a trigger", %{user: user} do
    {:ok, %Trigger{id: id, enabled: true}} = Triggers.new(%{name: "foo", pipeline: "echo stuff"})
    [payload] = user
    |> send_message("@bot: operable:trigger disable foo")

    assert %{id: ^id,
             name: "foo",
             enabled: false} = payload
  end

  test "deleting a trigger by name", %{user: user} do
    {:ok, %Trigger{id: id}} = Triggers.new(%{name: "foo", pipeline: "echo stuff"})
    [payload] = user
    |> send_message("@bot: operable:trigger delete foo")

    assert %{id: ^id,
             name: "foo"} = payload

    refute Cog.Repo.get(Trigger, id)
  end

  test "deleting multiple triggers by name", %{user: user} do
    {:ok, %Trigger{id: foo_id}} = Triggers.new(%{name: "foo", pipeline: "echo stuff"})
    {:ok, %Trigger{id: bar_id}} = Triggers.new(%{name: "bar", pipeline: "echo stuff"})
    {:ok, %Trigger{id: baz_id}} = Triggers.new(%{name: "baz", pipeline: "echo stuff"})

    payload = user
    |> send_message("@bot: operable:trigger delete foo bar baz")
    |> Enum.sort_by(fn(m) -> m[:name] end)

    assert [%{id: ^bar_id,
              name: "bar"},
            %{id: ^baz_id,
              name: "baz"},
            %{id: ^foo_id,
              name: "foo"}]= payload

    for id <- [foo_id, bar_id, baz_id],
      do: refute Cog.Repo.get(Trigger, id)
  end

  test "passing an unknown subcommand fails", %{user: user} do
    response = send_message(user, "@bot: operable:trigger not-a-subcommand")
    assert_error_message_contains(response, "Whoops! An error occurred. Unknown subcommand 'not-a-subcommand'")
  end

end
