defmodule Cog.Models.TriggerTest do
  @moduledoc """
  Test side-effect-free Trigger model code (note `async: true`)
  """

  use Cog.ModelCase, async: true
  alias Cog.Models.Trigger

  @valid_attrs %{name: "echo_message",
                 pipeline: "echo $body.message > chat://#general"}

  test "trigger timeout must be an integer" do
    changeset = Trigger.changeset(%Trigger{}, %{timeout_sec: 100.123})
    assert {:timeout_sec, "is invalid"} in changeset.errors
  end

  test "trigger timeout must be greater than 0" do
    changeset = Trigger.changeset(%Trigger{}, %{timeout_sec: -1})
    assert {:timeout_sec,
            {"must be greater than %{count}", [count: 0]}} in changeset.errors
  end

  [:name, :pipeline] |> Enum.each(fn(field) ->
    test "#{inspect field} is required" do
      changeset = Trigger.changeset(%Trigger{}, %{})
      assert {unquote(field), "can't be blank"} in changeset.errors
    end
  end)

  test "trigger timeout defaults to 30 seconds" do
    changeset = Trigger.changeset(%Trigger{}, @valid_attrs)
    assert changeset.valid?
    assert 30 = Ecto.Changeset.get_field(changeset, :timeout_sec)
  end

  test "triggers are active by default" do
    changeset = Trigger.changeset(%Trigger{}, @valid_attrs)
    assert changeset.valid?
    assert Ecto.Changeset.get_field(changeset, :active)
  end

  test "triggers have no description by default" do
    changeset = Trigger.changeset(%Trigger{}, @valid_attrs)
    assert changeset.valid?
    assert nil == Ecto.Changeset.get_field(changeset, :description)
  end

  test "triggers have no configured user by default" do
    changeset = Trigger.changeset(%Trigger{}, @valid_attrs)
    assert changeset.valid?
    assert nil == Ecto.Changeset.get_field(changeset, :as_user)
  end

end
