defmodule Cog.Models.RelayGroup.Test do
  use Cog.ModelCase
  alias Cog.Models.RelayGroup

  setup do
    {:ok, [relay: relay("test_relay", "sekret"),
           relay_group: relay_group("test_relay_group"),
           bundle: bundle_version("test_bundle").bundle]}
  end

  test "deleting a relay group with a relay member", %{relay: relay, relay_group: relay_group} do
    :ok = Groupable.add_to(relay, relay_group)
    changeset = RelayGroup.changeset(relay_group, :delete)
    assert {:error, changeset} = Repo.delete(changeset)
    assert [id: {"cannot delete relay group that has relay members", []}] = changeset.errors
  end

  test "deleting a relay group with a bundle assigned", %{bundle: bundle, relay_group: relay_group} do
    :ok = Groupable.add_to(bundle, relay_group)
    changeset = RelayGroup.changeset(relay_group, :delete)
    assert {:error, changeset} = Repo.delete(changeset)
    assert [id: {"cannot delete relay group that has bundles assigned", []}] = changeset.errors
  end
end
