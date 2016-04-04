defmodule Cog.Models.EventHookTest do
  @moduledoc """
  Test side-effect-free EventHook model code (note `async: true`)
  """

  use Cog.ModelCase, async: true
  alias Cog.Models.EventHook

  @valid_attrs %{name: "echo_message",
                 pipeline: "echo $body.message > chat://#general"}

  test "hook timeout must be an integer" do
    changeset = EventHook.changeset(%EventHook{}, %{timeout_sec: 100.123})
    assert {:timeout_sec, "is invalid"} in changeset.errors
  end

  test "hook timeout must be greater than 0" do
    changeset = EventHook.changeset(%EventHook{}, %{timeout_sec: -1})
    assert {:timeout_sec,
            {"must be greater than %{count}", [count: 0]}} in changeset.errors
  end

  [:name, :pipeline] |> Enum.each(fn(field) ->
    test "#{inspect field} is required" do
      changeset = EventHook.changeset(%EventHook{}, %{})
      assert {unquote(field), "can't be blank"} in changeset.errors
    end
  end)

  test "hook timeout defaults to 30 seconds" do
    changeset = EventHook.changeset(%EventHook{}, @valid_attrs)
    assert changeset.valid?
    assert 30 = Ecto.Changeset.get_field(changeset, :timeout_sec)
  end

  test "hooks are active by default" do
    changeset = EventHook.changeset(%EventHook{}, @valid_attrs)
    assert changeset.valid?
    assert Ecto.Changeset.get_field(changeset, :active)
  end

  test "hooks have no description by default" do
    changeset = EventHook.changeset(%EventHook{}, @valid_attrs)
    assert changeset.valid?
    assert nil == Ecto.Changeset.get_field(changeset, :description)
  end

  test "hooks have no configured user by default" do
    changeset = EventHook.changeset(%EventHook{}, @valid_attrs)
    assert changeset.valid?
    assert nil == Ecto.Changeset.get_field(changeset, :as_user)
  end

end
