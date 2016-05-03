defmodule Cog.ETSWrapperTest do
  use ExUnit.Case, async: true
  alias Cog.ETSWrapper

  setup do
    table = :ets.new(:test_table, [:private])
    {:ok, %{table: table}}
  end

  test "lookup an existing value", %{table: table} do
    ETSWrapper.insert(table, "cheese", "burgers")
    assert {:ok, "burgers"} = ETSWrapper.lookup(table, "cheese")
  end

  test "lookup a missing value", %{table: table} do
    assert {:error, :unknown_key} = ETSWrapper.lookup(table, "cheese")
  end

  test "inserting a value", %{table: table} do
    assert {:ok, "burgers"} = ETSWrapper.insert(table, "cheese", "burgers")
  end

  test "deleting an existing value", %{table: table} do
    ETSWrapper.insert(table, "cheese", "burgers")
    assert {:ok, "burgers"} = ETSWrapper.delete(table, "cheese")
  end

  test "enumerating all keys and values", %{table: table} do
    ETSWrapper.insert(table, "cheese", "burgers")
    ETSWrapper.insert(table, "fried", "chicken")
    ETSWrapper.insert(table, "pizza", "bagel")

    {:ok, agent} = Agent.start_link(fn -> %{} end)

    ETSWrapper.each(table, fn key, value ->
      Agent.update(agent, &Map.put_new(&1, key, value))
    end)

    state = Agent.get(agent, &(&1))

    assert "burgers" = Map.get(state, "cheese")
    assert "chicken" = Map.get(state, "fried")
    assert "bagel"   = Map.get(state, "pizza")
  end
end
