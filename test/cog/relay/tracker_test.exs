defmodule Cog.Relay.Tracker.Test do
  use ExUnit.Case
  require Logger
  alias Cog.Relay.Tracker

  @relay_one "relay_one"
  @relay_two "relay_two"
  @relay_three "relay_three"

  test "adding a single bundle_version works" do
    bundle_version = bundle_spec("one", "1.0.0")
    tracker = Tracker.add_bundle_versions_for_relay(Tracker.new, @relay_one, [bundle_version])
    assert_relays(tracker, bundle_version, [@relay_one])
  end

  test "adding multiple bundle_versions works" do
    bundle_versions = ["bundle_one", "bundle_two", "bundle_three"] |> Enum.map(&bundle_spec(&1, "1.0.0"))
    tracker = Tracker.add_bundle_versions_for_relay(Tracker.new, @relay_one, bundle_versions)
    for bundle_version <- bundle_versions do
      assert_relays(tracker, bundle_version, [@relay_one])
    end
  end

  test "multiple relays can provide a bundle_version" do
    bundle_version = bundle_spec("bundle_one", "2.0.0")

    relays = [@relay_one, @relay_two, @relay_three]

    tracker = Tracker.new
    |> Tracker.add_bundle_versions_for_relay(@relay_one, [bundle_version])
    |> Tracker.add_bundle_versions_for_relay(@relay_two, [bundle_version])
    |> Tracker.add_bundle_versions_for_relay(@relay_three, [bundle_version])

    assert_relays(tracker, bundle_version, relays)
  end

  test "adding bundle_versions is an appending operation" do
    batch_1 = Enum.map(["a", "b", "c"], &bundle_spec(&1, "1.2.3"))
    batch_2 = Enum.map(["d", "e"], &bundle_spec(&1, "4.5.6"))

    tracker = Tracker.new
    |> Tracker.add_bundle_versions_for_relay(@relay_one, batch_1)
    |> Tracker.add_bundle_versions_for_relay(@relay_one, batch_2)

    for bundle_version <- Enum.concat(batch_1, batch_2) do
      assert_relays(tracker, bundle_version, [@relay_one])
    end
  end

  test "setting bundle_versions is an overwriting operation" do
    batch_1 = Enum.map(["a", "b", "c"], &bundle_spec(&1, "0.0.1"))
    batch_2 = Enum.map(["d", "e"], &bundle_spec(&1, "0.0.2"))

    tracker = Tracker.new
    |> Tracker.add_bundle_versions_for_relay(@relay_one, batch_1)
    |> Tracker.set_bundle_versions_for_relay(@relay_one, batch_2)

    for bundle_version <- batch_2 do
      assert_relays(tracker, bundle_version, [@relay_one])
    end

    for bundle_version <- batch_1 do
      assert_missing(bundle_version, tracker)
    end
  end

  test "dropping relays for bundle_version works" do
    # Arrange
    bundle_version = bundle_spec("a", "0.5.0")

    tracker = Tracker.new
    |> Tracker.add_bundle_versions_for_relay(@relay_one, [bundle_version])
    |> Tracker.set_bundle_versions_for_relay(@relay_two, [bundle_version])

    # Act
    tracker = Tracker.drop_bundle(tracker, "a", "0.5.0")

    # Assert
    assert_missing(bundle_version, tracker)
  end

  test "dropping relays for a non-existent bundle_version returns tracker unchanged" do
    tracker_before = Tracker.new
    tracker_after = Tracker.drop_bundle(tracker_before, "non_existent_bundle", "6.6.6")
    assert tracker_before == tracker_after
  end

  ########################################################################

  defp bundle_spec(name, version),
    do: {name, version}

  defp assert_missing(bundle_spec, tracker),
    do: assert [] = actual_relays(tracker, bundle_spec)

  defp assert_relays(tracker, bundle_spec, expected_relays),
    do: assert Enum.sort(expected_relays) == Enum.sort(actual_relays(tracker, bundle_spec))

  defp actual_relays(tracker, {name, version}) do
    case Tracker.relays(tracker, name, version) do
      {:ok, relays} -> relays
      {:error, _} -> []
    end
  end

end
