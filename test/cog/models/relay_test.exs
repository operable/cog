defmodule Cog.Models.Relay.Test do
  use Cog.ModelCase
  alias Cog.Models.Relay

  setup do
    {:ok, [relay: relay("test_relay", "sekret"),
           relay_group: relay_group("test_relay_group")]}
  end

  test "deleting a relay that is a member of a relay group", %{relay: relay, relay_group: relay_group} do
    :ok = Groupable.add_to(relay, relay_group)
    changeset = Relay.changeset(relay, %{})
    assert {:error, changeset} = Repo.delete(changeset)
    assert [id: {"cannot delete relay that is a member of a relay group", []}] = changeset.errors
  end
end
