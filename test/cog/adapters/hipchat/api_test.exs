defmodule Cog.Adapters.HipChat.APITest do
  use ExUnit.Case
  alias Cog.Adapters.HipChat

  @moduletag :hipchat

  setup do
    config = HipChat.Config.fetch_config!
    HipChat.API.start_link(config)
    :ok
  end

  test "looking up a room" do
    assert {:ok, %{id: 2223837, name: "ci_bot_testing"}} = HipChat.API.lookup_room(name: "ci_bot_testing")
  end

  test "looking up a room that doesn't exist"  do
    assert {:error, %{"message" => "Room 'banana_stand' not found"}} = HipChat.API.lookup_room(name: "banana_stand")
  end

  test "looking up a direct room" do
    assert {:ok, %{"direct" => 479543}} = HipChat.API.lookup_direct_room(user_id: 479543)
  end

  test "sending a message" do
    {:ok, room} = HipChat.API.lookup_room(name: "ci_bot_testing")
    assert {:ok, _} = HipChat.API.send_message(%{"id" => room.id}, "test")
  end
end
