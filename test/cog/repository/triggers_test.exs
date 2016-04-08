defmodule Cog.Repository.TriggersTest do
  use Cog.ModelCase, async: false

  alias Cog.Models.Trigger
  alias Cog.Repository.Triggers

  @missing_uuid "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"

  test "triggers can be retrieved by ID" do
    trigger = trigger(%{name: "echo"})
    {:ok, retrieved} = Triggers.trigger_definition(trigger.id)
    assert retrieved == trigger
  end

  test "retrieval by a non-existent ID is an error" do
    assert {:error, :not_found} = Triggers.trigger_definition(@missing_uuid)
  end

  test "retrieval by a non-UUID ID is an error" do
    assert {:error, :bad_id} = Triggers.trigger_definition("Not-A-Valid-ID")
  end

  test "triggers can be created from a map of attributes" do
    attrs = %{name: "echo_message",
              pipeline: "echo $body.message > chat://#general",
              as_user: "marvin"}
    {:ok, trigger} = Triggers.new(attrs)
    assert %Trigger{id: _,
                      name: "echo_message",
                      pipeline: "echo $body.message > chat://#general",
                      as_user: "marvin",
                      timeout_sec: 30,
                      active: true,
                      description: nil} = trigger
  end

  test "invalid attributes on creation result in an error" do
    assert {:error, %Ecto.Changeset{}} = Triggers.new(%{})
  end

  test "all triggers can be retrieved at once (sort order unspecified)" do
    assert [] = Triggers.all

    triggers = ["a", "b", "c"]
    |> Enum.map(&trigger(%{name: &1}))

    retrieved = Triggers.all

    assert length(triggers) == length(retrieved)
    for trigger <- triggers do
      assert trigger in retrieved
    end
  end

  test "a trigger can be deleted" do
    trigger = trigger(%{name: "echo"})
    {:ok, %Trigger{}=_deleted_trigger} = Triggers.delete(trigger)
    assert {:error, :not_found} = Triggers.trigger_definition(trigger.id)
  end

  test "trying to delete an already deleted trigger is an error" do
    trigger = trigger(%{name: "echo"})
    {:ok, %Trigger{}} = Triggers.delete(trigger)
    assert {:error, :not_found} = Triggers.delete(trigger)
  end

  test "a trigger can be updated" do
    %Trigger{id: id}= trigger = trigger(%{name: "echo"})
    {:ok, updated} = Triggers.update(trigger, %{name: "new-echo"})
    assert %Trigger{id: ^id,
                      name: "new-echo"} = updated
  end

  test "updates that violate constraints are errors" do
    %Trigger{id: id}= trigger = trigger(%{name: "echo"})
    assert {:error, %Ecto.Changeset{}} = Triggers.update(trigger, %{name: nil})
    assert {:ok, ^trigger} = Triggers.trigger_definition(id)
  end
end
