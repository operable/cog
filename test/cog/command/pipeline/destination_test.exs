defmodule Cog.Command.Pipeline.DestinationTest do
  use ExUnit.Case
  alias Cog.Command.Pipeline.Destination
  alias Cog.Chat.Room

  test "'here' is resolved to current room" do
    {:ok, resolved} = Destination.process(["here"],
                                           :sender,
                                           :origin_room,
                                           "test")

    assert [%Destination{output_level: :full,
                         raw: "here",
                         adapter: "test",
                         room: :origin_room}] = resolved
  end

  test "'me' is resolved to current user" do
    {:ok, resolved} = Destination.process(["me"],
                                           %{"id" => "user1"},
                                           :origin_room,
                                           "test")

    assert [%Destination{output_level: :full,
                         raw: "me",
                         adapter: "test",
                         room: %Room{id: "user1_dm",
                                     name: "user1",
                                     provider: "test",
                                     is_dm: true}}] == resolved
  end

  test "a room is looked up properly" do
    {:ok, resolved} = Destination.process(["some_other_place"],
                                           :sender,
                                           :origin_room,
                                           "test")

    assert [%Destination{output_level: :full,
                         raw: "some_other_place",
                         adapter: "test",
                         room: %Room{id: "some_other_place",
                                     name: "some_other_place",
                                     provider: "test",
                                     is_dm: false}}] == resolved
  end

  test "a chat:// prefix is properly resolved" do
    {:ok, resolved} = Destination.process(["chat://some_other_place"],
                                           :sender,
                                           :origin_room,
                                           "test")

    assert [%Destination{output_level: :full,
                         raw: "chat://some_other_place",
                         adapter: "test",
                         room: %Room{id: "some_other_place",
                                     name: "some_other_place",
                                     provider: "test",
                                     is_dm: false}}] == resolved
  end

  test "no given destinations results in an implicit 'here'" do
    {:ok, resolved} = Destination.process([],
                                          :sender,
                                          :origin_room,
                                          "test")

    assert [%Destination{output_level: :full,
                         raw: "here",
                         adapter: "test",
                         room: :origin_room}] = resolved
  end

  test "no given destinations results in an implicit full-output 'here' for non-chat adapters" do
    {:ok, resolved} = Destination.process([],
                                          :sender,
                                          :origin_room,
                                          "http")

    assert [%Destination{output_level: :full,
                         raw: "here",
                         adapter: "http",
                         room: :origin_room}] = resolved
  end

  test "no explicit 'here' generates a status-only output 'here' for non-chat adapters" do
    {:ok, resolved} = Destination.process(["chat://#general"],
                                          :sender,
                                          :origin_room,
                                          "http")

    expected = [%Destination{output_level: :status_only,
                             raw: "here",
                             adapter: "http",
                             room: :origin_room},
                %Destination{output_level: :full,
                             raw: "chat://#general",
                             adapter: "test",
                             room: %Room{id: "#general",
                                         name: "#general",
                                         provider: "test",
                                         is_dm: false}}]

    assert Enum.sort(expected) == Enum.sort(resolved)
  end

  test "explicit 'here' resolves as a full-output 'here' for non-chat adapters" do

    {:ok, resolved} = Destination.process(["chat://#general",
                                           "here"],
                                          :sender,
                                          :origin_room,
                                          "http")

    expected = [%Destination{output_level: :full,
                             raw: "chat://#general",
                             adapter: "test",
                             room: %Room{id: "#general",
                                         name: "#general",
                                         provider: "test",
                                         is_dm: false}},
                %Destination{output_level: :full,
                             raw: "here",
                             adapter: "http",
                             room: :origin_room}]

    assert Enum.sort(expected) == Enum.sort(resolved)
  end

end
