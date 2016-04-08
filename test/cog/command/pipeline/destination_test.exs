defmodule Cog.Command.Pipeline.DestinationTest do
  use ExUnit.Case
  alias Cog.Command.Pipeline.Destination

  defmodule DestinationTestAdapter do
    use Cog.Adapter

    def send_message(_,_),
      do: raise "Not used in test"

    def lookup_room("@" <> user),
      do: {:ok, %{id: user, name: "direct"}}
    def lookup_room("#" <> room),
      do: {:ok, %{id: room, name: room}}
    def lookup_room(room_or_user),
      do: {:ok, %{id: room_or_user, name: room_or_user}}

    def lookup_user(handle: "vansterminator"),
      do: {:ok, %{id: "U024BE7LG", handle: "vansterminator"}}
    def lookup_user(handle: "updated-user"),
      do: {:ok, %{id: "U024BE7LK", handle: "updated-user"}}
    def lookup_user(handle: handle),
      do: {:ok, %{id: handle, handle: handle}}

    def lookup_direct_room(_user_id),
      do: {:ok, %{id: "channel1"}}

    def room_writeable?(_opts),
      do: true

    def mention_name(name),
      do: "@" <> name

    def name,
      do: "destination-test"

    def display_name,
      do: "Destination Test"
  end

  defmodule DestinationTestNonChatAdapter do
    use Cog.Adapter

    def name,
      do: "destination-test-not-chat"

    def chat_adapter?,
      do: false

    ##################################

    def send_message(_,_),
      do: raise "Not used in test"

    def lookup_room(_),
      do: raise "Not used in test"

    def lookup_user(_),
      do: raise "Not used in test"

    def lookup_direct_room(_),
      do: raise "Not used in test"

    def room_writeable?(_),
      do: raise "Not used in test"

    def mention_name(_),
      do: raise "Not used in test"

    def display_name,
      do: raise "Not used in test"

  end

  test "'here' is resolved to current room" do
    {:ok, resolved} = Destination.process(["here"],
                                           :sender,
                                           :origin_room,
                                           DestinationTestAdapter)

    assert [%Destination{output_level: :full,
                         raw: "here",
                         adapter: "destination-test",
                         room: :origin_room}] = resolved
  end

  test "'me' is resolved to current user" do
    {:ok, resolved} = Destination.process(["me"],
                                           %{"id" => "sender"},
                                           :origin_room,
                                           DestinationTestAdapter)

    assert [%Destination{output_level: :full,
                         raw: "me",
                         adapter: "destination-test",
                         room: %{id: "channel1"}}] = resolved
  end

  test "a room is looked up properly" do
    {:ok, resolved} = Destination.process(["some_other_place"],
                                           :sender,
                                           :origin_room,
                                           DestinationTestAdapter)

    assert [%Destination{output_level: :full,
                         raw: "some_other_place",
                         adapter: "destination-test",
                         room: %{id: "some_other_place",
                                 name: "some_other_place"}}] = resolved
  end

  test "a chat:// prefix is properly resolved" do
    flunk_if_not_expected_chat_adapter

    {:ok, resolved} = Destination.process(["chat://some_other_place"],
                                           :sender,
                                           :origin_room,
                                           DestinationTestAdapter)

    assert [%Destination{output_level: :full,
                         raw: "chat://some_other_place",
                         adapter: "test",
                         room: %{id: "some_other_place",
                                 name: "some_other_place"}}] = resolved
  end

  test "no given destinations results in an implicit 'here'" do
    {:ok, resolved} = Destination.process([],
                                          :sender,
                                          :origin_room,
                                          DestinationTestAdapter)

    assert [%Destination{output_level: :full,
                         raw: "here",
                         adapter: "destination-test",
                         room: :origin_room}] = resolved
  end

  test "no given destinations results in an implicit full-output 'here' for non-chat adapters" do
    {:ok, resolved} = Destination.process([],
                                          :sender,
                                          :origin_room,
                                          DestinationTestNonChatAdapter)

    assert [%Destination{output_level: :full,
                         raw: "here",
                         adapter: "destination-test-not-chat",
                         room: :origin_room}] = resolved
  end

  test "no explicit 'here' generates a status-only output 'here' for non-chat adapters" do
    flunk_if_not_expected_chat_adapter

    {:ok, resolved} = Destination.process(["chat://#general"],
                                          :sender,
                                          :origin_room,
                                          DestinationTestNonChatAdapter)

    expected = [%Destination{output_level: :status_only,
                             raw: "here",
                             adapter: "destination-test-not-chat",
                             room: :origin_room},
                %Destination{output_level: :full,
                             raw: "chat://#general",
                             adapter: "test",
                             room: %{id: "general", name: "general"}}]

    assert Enum.sort(expected) == Enum.sort(resolved)
  end

  test "explicit 'here' resolves as a full-output 'here' for non-chat adapters" do
    flunk_if_not_expected_chat_adapter

    {:ok, resolved} = Destination.process(["chat://#general",
                                           "here"],
                                          :sender,
                                          :origin_room,
                                          DestinationTestNonChatAdapter)

    expected = [%Destination{output_level: :full,
                             raw: "here",
                             adapter: "destination-test-not-chat",
                             room: :origin_room},
                %Destination{output_level: :full,
                             raw: "chat://#general",
                             adapter: "test",
                             room: %{id: "general", name: "general"}}]

    assert Enum.sort(expected) == Enum.sort(resolved)
  end

  # Just a helpful guide as we refactor tests in the future to be a
  # bit more flexible... there's currently some dependency on global
  # state, which would be nice to remove if we can.
  defp flunk_if_not_expected_chat_adapter do
    {:ok, current} = Cog.chat_adapter_module
    assert(current == Cog.Adapters.Test,
           "This test depends on the globally-configured chat adapter being Cog.Adapters.Test, but it is #{inspect current} instead ")
  end

end
