defmodule Cog.ETSTest do
  use ExUnit.Case, async: true
  alias Cog.ETS

  setup do
    table = :ets.new(:test_table, [:private])
    {:ok, %{table: table}}
  end

  test "lookup an existing value", %{table: table} do
    ETS.insert(table, "cheese", "burgers")
    assert {:ok, "burgers"} = ETS.lookup(table, "cheese")
  end

  test "lookup a missing value", %{table: table} do
    assert {:error, :unknown_key} = ETS.lookup(table, "cheese")
  end

  test "inserting a value", %{table: table} do
    assert {:ok, "burgers"} = ETS.insert(table, "cheese", "burgers")
  end

  test "deleting an existing value", %{table: table} do
    ETS.insert(table, "cheese", "burgers")
    assert {:ok, "burgers"} = ETS.delete(table, "cheese")
  end

  test "enumerating all keys and values", %{table: table} do
    ETS.insert(table, "cheese", "burgers")
    ETS.insert(table, "fried", "chicken")
    ETS.insert(table, "pizza", "bagel")

    {:ok, agent} = Agent.start_link(fn -> %{} end)

    ETS.each(table, fn key, value ->
      Agent.update(agent, &Map.put_new(&1, key, value))
    end)

    state = Agent.get(agent, &(&1))

    assert "burgers" = Map.get(state, "cheese")
    assert "chicken" = Map.get(state, "fried")
    assert "bagel"   = Map.get(state, "pizza")
  end
end
