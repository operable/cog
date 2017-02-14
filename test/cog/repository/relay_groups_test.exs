defmodule Cog.Repository.RelayGroupsTest do
  use Cog.ModelCase, async: false

  alias Cog.Repository.Bundles
  alias Cog.Repository.RelayGroups
  alias Cog.Repository.Relays

  test "deleting a relay group with assigned bundles is not allowed" do
    {:ok, bundle} = Bundles.install(%{"name" => "foo",
                                      "version" => "1.0.0",
                                      "config_file" => %{}})

    {:ok, relay_group} = RelayGroups.new(%{"name" => "test_group"})
    {:ok, relay_group} = RelayGroups.manage_association(relay_group,
                                                        %{"bundles" =>
                                                           %{"add" => [bundle.bundle_id]}})

    assert {:error, changeset} = RelayGroups.delete(relay_group)
    assert [id: {"cannot delete relay group that has bundles assigned", []}] = changeset.errors
  end


  test "deleting a relay group with relay members is not allowed" do
    {:ok, relay} = Relays.new(%{"name" => "my_relay",
                                "token" => "my_token"})

    {:ok, relay_group} = RelayGroups.new(%{"name" => "test_group"})
    {:ok, relay_group} = RelayGroups.manage_association(relay_group,
                                                        %{"relays" =>
                                                           %{"add" => [relay.id]}})

    assert {:error, changeset} = RelayGroups.delete(relay_group)
    assert [id: {"cannot delete relay group that has relay members", []}] = changeset.errors
  end



end
