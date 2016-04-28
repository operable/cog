defmodule Cog.Command.Service.MemoryTest do
  use ExUnit.Case, async: true

  alias Cog.Command.Service.Memory
  alias Cog.ServiceHelpers

  @token "d386da42-0c99-11e6-aa1c-db55971236aa"

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
end
