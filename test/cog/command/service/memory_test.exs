defmodule Cog.Command.Service.MemoryTest do
  use ExUnit.Case

  alias Cog.Command.Service.{Memory, Tokens}

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
    Memory.replace(@token, "drinks", {"cold brew"})
    assert {:error, :value_not_list} = Memory.accum(@token, "drinks", "cappuccino")
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
    {pid, token} = fake_executor

    Memory.replace(token, "bbq", "valentina's tex mex")

    send(pid, :exit_normally)
    :timer.sleep(500)

    assert {:error, :unknown_key} = Memory.fetch(token, "bbq")
  end

  test "cleaning up keys after a pipeline crashes" do
    {pid, token} = fake_executor

    Memory.replace(token, "bbq", "valentina's tex mex")

    send(pid, :crash)
    :timer.sleep(500)

    assert {:error, :unknown_key} = Memory.fetch(token, "bbq")
  end

  defp fake_executor do
    caller = self()
    pid = spawn(fn() ->
      token = Tokens.new
      send(caller, {:token, token, self()})
      receive do
        :exit_normally ->
          :ok
        :crash ->
          raise "BOOM!"
      after 2000 ->
          flunk "Timeout waiting to receive instruction in token consumer!"
      end
    end)

    receive do
      {:token, token, ^pid} ->
        {pid, token}
    after 1000 ->
        flunk "Timeout waiting to receive token!"
    end
  end
end
