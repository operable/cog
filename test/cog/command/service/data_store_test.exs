defmodule Cog.Command.Service.DataStoreTest do
  use ExUnit.Case, async: true

  alias Cog.Command.Service.DataStore

  @base_path Application.get_env(:cog, Cog.Command.Service)[:data_path]
  @namespace [ "test", "data_store" ]
  @test_keys [ "foo", "foo1", "foo2", "foo3" ]

  setup_all do
    Ecto.Adapters.SQL.Sandbox.checkout(Cog.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Cog.Repo, {:shared, self()})

    pid = Process.whereis(DataStore)
    Process.unregister(DataStore)

    on_exit(fn ->
      Process.register(pid, DataStore)
    end)

    :ok
  end

  setup do
    {:ok, pid} = DataStore.start_link(@base_path)

    # Cleanup any existing objects that are named the same as those
    # that are used in this test to ensure a clean slate to test from.
    Enum.each(@test_keys, fn(k) -> DataStore.delete(@namespace, k) end)

    {:ok, %{pid: pid}}
  end

  test "fetch an existing key" do
    foo = %{"foo" => "fooval"}
    DataStore.replace(@namespace, "foo", foo)
    assert {:ok, ^foo} = DataStore.fetch(@namespace, "foo")
  end

  test "fetch an unset key" do
    assert {:error, "Object not found"} = DataStore.fetch(@namespace, "cheeseburgers")
  end

  test "replacing an unset key" do
    foo1 = %{"foo1" => "fooval"}
    DataStore.replace(@namespace, "foo1", foo1)
    assert {:ok, ^foo1} = DataStore.fetch(@namespace, "foo1")
  end

  test "replacing an existing key" do
    foo2 = %{"foo2" => "fooval"}
    notfoo2 = %{"notfoo2" => "nope"}

    DataStore.replace(@namespace, "foo2", notfoo2)
    assert {:ok, ^notfoo2} = DataStore.fetch(@namespace, "foo2")

    DataStore.replace(@namespace, "foo2", foo2)
    assert {:ok, ^foo2} = DataStore.fetch(@namespace, "foo2")
  end

  test "deleting an existing key" do
    foo3 = %{"foo3" => "fooval"}

    DataStore.replace(@namespace, "foo3", foo3)
    assert {:ok, "foo3"} = DataStore.delete(@namespace, "foo3")
    assert {:error, "Object not found"} = DataStore.fetch(@namespace, "foo3")
  end

  test "deleting an unset key" do
    assert {:error, "Object not found"} = DataStore.delete(@namespace, "bar")
  end
end
