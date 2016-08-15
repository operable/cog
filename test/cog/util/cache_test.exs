defmodule Util.CacheTest do

  use ExUnit.Case, async: true

  alias Cog.Util.Cache
  alias Cog.Util.CacheSup

  setup do
    case :erlang.whereis(Cog.Util.CacheSup) do
      :undefined ->
        {:ok, _pid} = Cog.Util.CacheSup.start_link
        :ok
      pid when is_pid(pid) ->
        :ok
    end
  end

  test "ttl == 0 disables cache" do
    {:ok, cache} = CacheSup.create_cache(:disabled_cache, {0, :sec})
    Cache.put(cache, "testing", 123)
    assert cache["testing"] == nil
    Cache.close(cache)
  end

  test "ttl < 0 disables cache" do
    {:ok, cache} = CacheSup.create_cache(:disabled_cache, {-1, :sec})
    Cache.put(cache, "testing", 123)
    assert cache["testing"] == nil
    Cache.close(cache)
  end

  test "entries expire properly" do
    {:ok, cache} = CacheSup.create_cache(:user_cache, {1, :sec})
    Cache.put(cache, "bob", [full_name: "Bob Belcher"])
    assert cache["bob"] == [full_name: "Bob Belcher"]
    :timer.sleep(1000)
    assert cache["bob"] == nil
    Cache.close(cache)
  end

end
