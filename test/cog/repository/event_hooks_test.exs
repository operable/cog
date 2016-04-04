defmodule Cog.Repository.EventHooksTest do
  use Cog.ModelCase, async: false

  alias Cog.Models.EventHook
  alias Cog.Repository.EventHooks

  @missing_uuid "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"

  test "hooks can be retrieved by ID" do
    hook = hook(%{name: "echo"})
    {:ok, retrieved} = EventHooks.hook_definition(hook.id)
    assert retrieved == hook
  end

  test "retrieval by a non-existent ID is an error" do
    assert {:error, :not_found} = EventHooks.hook_definition(@missing_uuid)
  end

  test "retrieval by a non-UUID ID is an error" do
    assert {:error, :bad_id} = EventHooks.hook_definition("Not-A-Valid-ID")
  end

  test "hooks can be created from a map of attributes" do
    attrs = %{name: "echo_message",
              pipeline: "echo $body.message > chat://#general",
              as_user: "marvin"}
    {:ok, hook} = EventHooks.new(attrs)
    assert %EventHook{id: _,
                      name: "echo_message",
                      pipeline: "echo $body.message > chat://#general",
                      as_user: "marvin",
                      timeout_sec: 30,
                      active: true,
                      description: nil} = hook
  end

  test "invalid attributes on creation result in an error" do
    assert {:error, %Ecto.Changeset{}} = EventHooks.new(%{})
  end

  test "all hooks can be retrieved at once (sort order unspecified)" do
    assert [] = EventHooks.all

    hooks = ["a", "b", "c"]
    |> Enum.map(&hook(%{name: &1}))

    retrieved = EventHooks.all

    assert length(hooks) == length(retrieved)
    for hook <- hooks do
      assert hook in retrieved
    end
  end

  test "a hook can be deleted" do
    hook = hook(%{name: "echo"})
    {:ok, %EventHook{}=_deleted_hook} = EventHooks.delete(hook)
    assert {:error, :not_found} = EventHooks.hook_definition(hook.id)
  end

  test "trying to delete an already deleted hook is an error" do
    hook = hook(%{name: "echo"})
    {:ok, %EventHook{}} = EventHooks.delete(hook)
    assert {:error, :not_found} = EventHooks.delete(hook)
  end

  test "a hook can be updated" do
    %EventHook{id: id}= hook = hook(%{name: "echo"})
    {:ok, updated} = EventHooks.update(hook, %{name: "new-echo"})
    assert %EventHook{id: ^id,
                      name: "new-echo"} = updated
  end

  test "updates that violate constraints are errors" do
    %EventHook{id: id}= hook = hook(%{name: "echo"})
    assert {:error, %Ecto.Changeset{}} = EventHooks.update(hook, %{name: nil})
    assert {:ok, ^hook} = EventHooks.hook_definition(id)
  end
end
