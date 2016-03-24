defmodule Cog.Adapters.HipChat.APITest do
  use ExUnit.Case, async: false
  use Cog.VCR
  alias Cog.Adapters.HipChat

  @moduletag :hipchat

  setup do
    config = HipChat.Config.fetch_config!
    {:ok, %{config: config}}
  end

  test "looking up a room", %{config: config} do
    use_cassette do
      HipChat.API.start_link(config)
      assert {:ok, %{id: 2223837, name: "ci_bot_testing"}} = HipChat.API.lookup_room(name: "ci_bot_testing")
    end
  end

  test "looking up a room that doesn't exist", %{config: config} do
    use_cassette do
      HipChat.API.start_link(config)
      assert {:error, %{"message" => "Room 'banana_stand' not found"}} = HipChat.API.lookup_room(name: "banana_stand")
    end
  end

  test "looking up a direct room", %{config: config} do
    use_cassette do
      HipChat.API.start_link(config)
      assert {:ok, %{"direct" => 479543}} = HipChat.API.lookup_direct_room(user_id: 479543)
    end
  end

  test "sending a message", %{config: config} do
    use_cassette do
      HipChat.API.start_link(config)
      {:ok, room} = HipChat.API.lookup_room(name: "ci_bot_testing")
      assert {:ok, _} = HipChat.API.send_message(%{"id" => room.id}, "test")
    end
  end
end
