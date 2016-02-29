defmodule Cog.Relay.Tracker.Test do
  use ExUnit.Case
  require Logger
  alias Cog.Relay.Tracker
  alias Cog.Models.Bundle

  @relay_one "relay_one"
  @relay_two "relay_two"
  @relay_three "relay_three"

  test "adding a single bundle works" do
    bundle = bundle("one")
    tracker = Tracker.add_bundles_for_relay(Tracker.new, @relay_one, [bundle])
    assert_relays(tracker, bundle, [@relay_one])
  end

  test "adding multiple bundles works" do
    bundles = ["bundle_one", "bundle_two", "bundle_three"] |> Enum.map(&bundle/1)
    tracker = Tracker.add_bundles_for_relay(Tracker.new, @relay_one, bundles)
    for bundle <- bundles do
      assert_relays(tracker, bundle, [@relay_one])
    end
  end

  test "multiple relays can provide a bundle" do
    bundle = bundle("bundle_one")

    relays = [@relay_one, @relay_two, @relay_three]

    tracker = Tracker.new
    |> Tracker.add_bundles_for_relay(@relay_one, [bundle])
    |> Tracker.add_bundles_for_relay(@relay_two, [bundle])
    |> Tracker.add_bundles_for_relay(@relay_three, [bundle])

    assert_relays(tracker, bundle, relays)
  end

  test "adding bundles is an appending operation" do
    batch_1 = Enum.map(["a", "b", "c"], &bundle/1)
    batch_2 = Enum.map(["d", "e"], &bundle/1)

    tracker = Tracker.new
    |> Tracker.add_bundles_for_relay(@relay_one, batch_1)
    |> Tracker.add_bundles_for_relay(@relay_one, batch_2)

    for bundle <- Enum.concat(batch_1, batch_2) do
      assert_relays(tracker, bundle, [@relay_one])
    end
  end

  test "setting bundles is an overwriting operation" do
    batch_1 = Enum.map(["a", "b", "c"], &bundle/1)
    batch_2 = Enum.map(["d", "e"], &bundle/1)

    tracker = Tracker.new
    |> Tracker.add_bundles_for_relay(@relay_one, batch_1)
    |> Tracker.set_bundles_for_relay(@relay_one, batch_2)

    for bundle <- batch_2 do
      assert_relays(tracker, bundle, [@relay_one])
    end

    for bundle <- batch_1 do
      assert_missing(bundle, tracker)
    end
  end

  test "dropping relays for bundle works" do
    # Arrange
    bundle = bundle("a")

    tracker = Tracker.new
    |> Tracker.add_bundles_for_relay(@relay_one, [bundle])
    |> Tracker.set_bundles_for_relay(@relay_two, [bundle])

    # Act
    tracker = Tracker.drop_bundle(tracker, bundle)

    # Assert
    assert_missing(bundle, tracker)
  end

  test "dropping relays for a non-existent bundle returns tracker unchanged" do
    tracker_before = Tracker.new
    tracker_after = Tracker.drop_bundle(tracker_before, "non_existent_bundle")
    assert tracker_before == tracker_after
  end

  ########################################################################

  defp bundle(name),
    do: %Bundle{name: name}

  defp assert_missing(bundle, tracker),
    do: assert [] = Tracker.relays(tracker, bundle)

  defp assert_relays(tracker, bundle, expected_relays) do
    actual_relays = Tracker.relays(tracker, bundle.name)
    assert Enum.sort(expected_relays) == Enum.sort(actual_relays)
  end

end
