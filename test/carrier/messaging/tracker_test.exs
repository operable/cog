defmodule Carrier.Messaging.TrackerTest do

  use ExUnit.Case, async: true

  alias Carrier.Messaging.Tracker

  defp placeholder() do
    spawn(fn() ->
      receive do
        _ ->
          :ok
      end end)
  end

  test "adding subscription" do
    p1 = placeholder()
    tracker = %Tracker{}
    tracker = Tracker.add_subscription(tracker, "foo/bar", p1)
    assert Tracker.find_subscribers(tracker, "foo/bar") == [p1]
  end

  test "adding/removing subscriptions" do
    p1 = placeholder()
    tracker = %Tracker{}
    tracker = Tracker.add_subscription(tracker, "foo/bar", p1)
    {tracker, true} = Tracker.del_subscription(tracker, "foo/bar", p1)
    assert Tracker.find_subscribers(tracker, "foo/bar") == []
  end

  test "multiple subscribers" do
    p1 = placeholder()
    p2 = placeholder()
    tracker = %Tracker{}
    tracker = Tracker.add_subscription(tracker, "foo/bar", p1)
    tracker = Tracker.add_subscription(tracker, "foo/bar", p2)
    subs = Tracker.find_subscribers(tracker, "foo/bar")
    assert Enum.member?(subs, p1)
    assert Enum.member?(subs, p2)
    tracker = Tracker.del_subscriber(tracker, p1)
    assert Tracker.find_subscribers(tracker, "foo/bar") == [p2]
  end

  test "single level wildcard subscriptions" do
    p1 = placeholder()
    tracker = %Tracker{}
    tracker = Tracker.add_subscription(tracker, "foo/bar/+", p1)
    assert Tracker.find_subscribers(tracker, "foo/bar/baz") == [p1]
    assert Tracker.find_subscribers(tracker, "foo/bar/baz/quux") == []
  end

  test "multi level wildcard subscriptions" do
    p1 = placeholder()
    p2 = placeholder()
    tracker = %Tracker{}
    tracker = tracker
              |> Tracker.add_subscription("foo/bar/+", p1)
              |> Tracker.add_subscription("foo/bar/*", p2)
    subs = Tracker.find_subscribers(tracker, "foo/bar/baz")
    assert Enum.member?(subs, p1)
    assert Enum.member?(subs, p2)
    assert Tracker.find_subscribers(tracker, "foo/bar/baz/quux") == [p2]
    assert Tracker.find_subscribers(tracker, "foo/ba/baz") == []
  end

  test "removing subscriber works" do
    p1 = placeholder()
    p2 = placeholder()
    tracker = %Tracker{}
    tracker = tracker
              |> Tracker.add_subscription("foo/bar", p1)
              |> Tracker.add_subscription("quux", p1)
              |> Tracker.add_subscription("baz", p2)
              |> Tracker.add_subscription("quux", p2)
    tracker = Tracker.del_subscriber(tracker, p1)
    assert Tracker.find_subscribers(tracker, "quux") == [p2]
    assert Enum.count(tracker.monitors) == 1
    tracker = Tracker.del_subscriber(tracker, p2)
    assert Tracker.unused?(tracker)
  end

  test "handle unknown processes" do
    p1 = placeholder()
    p2 = placeholder()
    tracker = %Tracker{}
    tracker = Tracker.add_subscription(tracker, "foo", p1)
    {tracker, false} = Tracker.del_subscription(tracker, "foo", p2)
    refute Tracker.unused?(tracker)
    assert Tracker.find_subscribers(tracker, "foo") == [p1]
    tracker = Tracker.del_subscriber(tracker, p2)
    refute Tracker.unused?(tracker)
    assert Tracker.find_subscribers(tracker, "foo") == [p1]
    tracker = Tracker.del_subscriber(tracker, p1)
    assert Tracker.unused?(tracker)
  end

  test "unused? predicate functions" do
    p1 = placeholder()
    tracker = %Tracker{}
              |> Tracker.add_subscription("foo/bar", p1)
              |> Tracker.add_subscription("baz/quux", p1)
    refute Tracker.unused?(tracker)
    {tracker1, _} = Tracker.del_subscription(tracker, "foo/bar", p1)
    assert tracker != tracker1
    refute Tracker.unused?(tracker1)
    tracker2 = Tracker.del_subscriber(tracker1, p1)
    assert tracker2 != tracker1
    assert Tracker.unused?(tracker2)
    {tracker3, unused_topics} = Tracker.get_and_reset_unused_topics(tracker2)
    assert tracker3 != tracker2
    assert Enum.sort(unused_topics) == ["baz/quux", "foo/bar"]
  end

end
