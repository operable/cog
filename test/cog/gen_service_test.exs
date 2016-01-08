defmodule Cog.GenServiceTest do
  use ExUnit.Case
  alias Cog.GenService

  defmodule TestCacheService do
    use GenService

    # Only used to initialize ets
    def service_init(_) do
      cache_create
      {:ok, []}
    end

    def handle_message("is_cache_set", _req, _state) do
      key = "is_cache_set"

      case cache_lookup(key) do
        nil ->
          cache_insert(true, key)
          false
        _ ->
          true
      end
    end
  end

  defmodule SimpleService do
    use GenService
  end

  defmodule Service.With.A.CustomName do
    use GenService, name: "nifty-service"
  end

  defmodule NotAService do
    def hello(), do: "Hello World!"
  end

  test "inserting and looking up items in the cache" do
    {:ok, []} = TestCacheService.service_init([])

    refute TestCacheService.handle_message("is_cache_set", :fake_req, :fake_state)
    assert TestCacheService.handle_message("is_cache_set", :fake_req, :fake_state)
    assert TestCacheService.handle_message("is_cache_set", :fake_req, :fake_state)
  end

  test "looking up stale items from the cache" do
    # Make all items immediately stale
    env = Application.get_env(:cog, :services)
    Application.put_env(:cog, :services, Keyword.merge(env, [testcacheservice_cache_ttl: -1]))

    {:ok, []} = TestCacheService.service_init([])

    refute TestCacheService.handle_message("is_cache_set", :fake_req, :fake_state)
    refute TestCacheService.handle_message("is_cache_set", :fake_req, :fake_state)

    # Reset env
    Application.put_env(:cog, :services, env)
  end

  test "service modules are marked as such" do
    assert GenService.is_service?(SimpleService)
    refute GenService.is_service?(NotAService)
  end

  test "services have default names" do
    assert SimpleService.name == "simpleservice"
  end

  test "services can override their default name" do
    assert Service.With.A.CustomName.name == "nifty-service"
  end

end
