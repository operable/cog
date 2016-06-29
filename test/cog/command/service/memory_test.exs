defmodule Cog.Command.Service.MemoryTest do
  use ExUnit.Case, async: true

  alias Cog.Command.Service.Memory
  alias Cog.ServiceHelpers

  @token "d386da42-0c99-11e6-aa1c-db55971236aa"

  setup_all do
    Ecto.Adapters.SQL.Sandbox.checkout(Cog.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Cog.Repo, {:shared, self()})

    pid = Process.whereis(Memory)
    Process.unregister(Memory)

    on_exit(fn ->
      Process.register(pid, Memory)
    end)

    :ok
  end

  setup do
    memory_table  = :ets.new(:test_memory_table,  [:public])
    monitor_table = :ets.new(:test_monitor_table, [:public])

    {:ok, pid} = Memory.start_link(memory_table, monitor_table)

    {:ok, %{pid: pid, memory_table: memory_table, monitor_table: monitor_table}}
  end

  test "fetch an existing key" do
    donuts = ["old-fashioned", "chocolate-with-sprinkles"]
    Memory.replace(@token, "donuts", donuts)
    assert {:ok, ^donuts} = Memory.fetch(@token, "donuts")
  end

  test "fetch an unset key" do
    assert {:error, :unknown_key} = Memory.fetch(@token, "cheeseburgers")
  end

  test "accumulating a list into an unset key" do
    toppings = ["pepperoni", "bacon", "avocado"]

    for topping <- toppings,
      do: Memory.accum(@token, "pizza-toppings", topping)

    assert {:ok, ^toppings} = Memory.fetch(@token, "pizza-toppings")
  end

  test "accumulating into a non-list key" do
    Memory.replace(@token, "drinks", "cold brew")
    assert {:ok, ["cold brew", "cappuccino"]} = Memory.accum(@token, "drinks", "cappuccino")
  end

  test "joining into an unset key" do
    breakfasts = [["eggs"], ["cinnamon rolls"], ["bacon", "cold pizza"]]

    for breakfast <- breakfasts,
      do: Memory.join(@token, "breakfast", breakfast)

    assert {:ok, ["eggs", "cinnamon rolls", "bacon", "cold pizza"]} = Memory.fetch(@token, "breakfast")
  end

  test "joining into a non-list" do
    Memory.replace(@token, "ice cream", "chocolate")
    assert {:error, :value_not_list} = Memory.join(@token, "ice cream", ["vanilla"])
  end

  test "joining a non-list" do
    Memory.replace(@token, "steak", ["rib eye"])
    assert {:error, :value_not_list} = Memory.join(@token, "steak", "new yourk strip")
  end

  test "replacing an unset key" do
    Memory.replace(@token, "beer", "yo-ho tokyo black porter")
    assert {:ok, "yo-ho tokyo black porter"} = Memory.fetch(@token, "beer")
  end

  test "replacing an existing key" do
    Memory.replace(@token, "taco", "akaushi beef")
    assert {:ok, "akaushi beef"} = Memory.fetch(@token, "taco")

    Memory.replace(@token, "taco", "space cowboy")
    assert {:ok, "space cowboy"} = Memory.fetch(@token, "taco")
  end

  test "deleting an existing key" do
    Memory.replace(@token, "bourbon", "pappy van winkle")
    assert {:ok, "pappy van winkle"} = Memory.delete(@token, "bourbon")
    assert {:error, :unknown_key} = Memory.fetch(@token, "bourbon")
  end

  test "deleting an unset key" do
    assert {:error, :unknown_key} = Memory.delete(@token, "tequila")
  end

  test "cleaning up keys once a pipeline exits normally" do
    {pid, token} = ServiceHelpers.spawn_fake_executor

    Memory.replace(token, "bbq", "valentina's tex mex")

    send(pid, :exit_normally)
    :timer.sleep(500)

    assert {:error, :unknown_key} = Memory.fetch(token, "bbq")
  end

  test "cleaning up keys after a pipeline crashes" do
    {pid, token} = ServiceHelpers.spawn_fake_executor

    Memory.replace(token, "bbq", "valentina's tex mex")

    send(pid, :crash)
    :timer.sleep(500)

    assert {:error, :unknown_key} = Memory.fetch(token, "bbq")
  end

  test "removing keys of processes that died during a restart", context do
    {pid, token} = ServiceHelpers.spawn_fake_executor

    Memory.replace(token, "bbq", "valentina's tex mex")

    # Kill memory process
    Process.unlink(context.pid)
    Process.exit(context.pid, :kill)
    :timer.sleep(500)

    # Kill fake executor process
    send(pid, :crash)
    :timer.sleep(500)

    # Startup memory process; it doesn't know about the dead executor yet
    {:ok, _pid} = Memory.start_link(context.memory_table, context.monitor_table)

    assert {:error, :unknown_key} = Memory.fetch(token, "bbq")
  end

  test "monitoring processes present after a restart", context do
    {pid, token} = ServiceHelpers.spawn_fake_executor

    Memory.replace(token, "bbq", "valentina's tex mex")

    # Kill memory process
    Process.unlink(context.pid)
    Process.exit(context.pid, :kill)
    :timer.sleep(500)

    # Startup memory process; without the old monitor
    {:ok, _pid} = Memory.start_link(context.memory_table, context.monitor_table)

    # Kill fake executor process
    send(pid, :crash)
    :timer.sleep(500)

    assert {:error, :unknown_key} = Memory.fetch(token, "bbq")
  end
end
