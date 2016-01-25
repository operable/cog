defmodule Cog.Relay.Tracker.Test do
  use ExUnit.Case
  require Logger
  alias Cog.Relay.Tracker
  alias Cog.Models.Bundle

  @relay_one "relay_one"
  @relay_two "relay_two"
  @relay_three "relay_three"

  test "adding a single bundle works" do
    bundle = enabled_bundle("one")
    tracker = Tracker.add_bundles_for_relay(Tracker.new, @relay_one, [bundle])
    assert_enabled(bundle, [@relay_one], tracker)
  end

  test "adding a new disabled bundle works" do
    bundle = disabled_bundle("one")
    tracker = Tracker.add_bundles_for_relay(Tracker.new, @relay_one, [bundle])
    assert_disabled(bundle, [@relay_one], tracker)
  end

  test "adding multiple bundles works" do
    bundles = ["bundle_one", "bundle_two", "bundle_three"] |> Enum.map(&enabled_bundle/1)
    tracker = Tracker.add_bundles_for_relay(Tracker.new, @relay_one, bundles)
    for bundle <- bundles do
      assert_enabled(bundle, [@relay_one], tracker)
    end
  end

  test "multiple relays can provide a bundle" do
    bundle = enabled_bundle("bundle_one")

    relays = [@relay_one, @relay_two, @relay_three]

    tracker = Tracker.new
    |> Tracker.add_bundles_for_relay(@relay_one, [bundle])
    |> Tracker.add_bundles_for_relay(@relay_two, [bundle])
    |> Tracker.add_bundles_for_relay(@relay_three, [bundle])

    assert_enabled(bundle, relays, tracker)
  end

  test "adding bundles is an appending operation" do
    batch_1 = Enum.map(["a", "b", "c"], &enabled_bundle/1)
    batch_2 = Enum.map(["d", "e"], &enabled_bundle/1)

    tracker = Tracker.new
    |> Tracker.add_bundles_for_relay(@relay_one, batch_1)
    |> Tracker.add_bundles_for_relay(@relay_one, batch_2)

    for bundle <- Enum.concat(batch_1, batch_2) do
      assert_enabled(bundle, [@relay_one], tracker)
    end
  end

  test "setting bundles is an overwriting operation" do
    batch_1 = Enum.map(["a", "b", "c"], &enabled_bundle/1)
    batch_2 = Enum.map(["d", "e"], &enabled_bundle/1)

    tracker = Tracker.new
    |> Tracker.add_bundles_for_relay(@relay_one, batch_1)
    |> Tracker.set_bundles_for_relay(@relay_one, batch_2)

    for bundle <- batch_2 do
      assert_enabled(bundle, [@relay_one], tracker)
    end

    for bundle <- batch_1 do
      assert_missing(bundle, tracker)
    end
  end

  test "dropping relays for bundle works" do
    # Arrange
    bundle = enabled_bundle("a")

    tracker = Tracker.new
    |> Tracker.add_bundles_for_relay(@relay_one, [bundle])
    |> Tracker.set_bundles_for_relay(@relay_two, [bundle])

    # Act
    tracker = Tracker.drop_bundle(tracker, bundle)

    # Assert
    assert_missing(bundle, tracker)
  end

  test "dropping relays for a non-existent returns tracker unchanged" do
    tracker_before = Tracker.new
    tracker_after = Tracker.drop_bundle(tracker_before, "non_existent_bundle")
    assert tracker_before == tracker_after
  end

  test "deactivating an existing bundle" do
    bundle = enabled_bundle("a")

    tracker = Tracker.new
    |> Tracker.add_bundles_for_relay(@relay_one, [bundle])

    tracker = Tracker.disable_bundle(tracker, bundle.name)
    assert_disabled(bundle, [@relay_one], tracker)
  end

  test "deactivating a non-existent bundle leaves tracker unchanged" do
    tracker = Tracker.new
    tracker_after = Tracker.disable_bundle(tracker, "non_existent_bundle")
    assert tracker == tracker_after
  end

  test "activating an existing bundle" do
    bundle = enabled_bundle("a")

    tracker = Tracker.new
    |> Tracker.add_bundles_for_relay(@relay_one, [bundle])
    |> Tracker.disable_bundle(bundle.name)

    assert_disabled(bundle, [@relay_one], tracker)

    tracker = Tracker.enable_bundle(tracker, bundle.name)

    Logger.warn(">>>>>>> tracker = #{inspect tracker}")

    assert_enabled(bundle, [@relay_one], tracker)
  end

  test "activating a non-existent bundle leaves tracker unchanged" do
    tracker = Tracker.new
    tracker_after = Tracker.enable_bundle(tracker, "non_existent_bundle")
    assert tracker == tracker_after
  end

  ########################################################################

  defp enabled_bundle(name),
    do: %Bundle{name: name, enabled: true}

  defp disabled_bundle(name),
    do: %Bundle{name: name, enabled: false}

  defp assert_enabled(bundle, expected_relays, tracker),
    do: assert_bundle_status(tracker, bundle, :enabled, expected_relays)

  defp assert_disabled(bundle, expected_relays, tracker),
    do: assert_bundle_status(tracker, bundle, :disabled, expected_relays)

  defp assert_missing(bundle, tracker),
    do: assert {:error, :no_relays_serving_bundle} = Tracker.bundle_status(tracker, bundle)

  defp assert_bundle_status(tracker, bundle, expected_status, expected_relays) do
    {:ok, %{relays: actual_relays, status: status}} = Tracker.bundle_status(tracker, bundle.name)
    assert status == expected_status
    assert Enum.sort(expected_relays) == Enum.sort(actual_relays)
  end

end
