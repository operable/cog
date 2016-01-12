defmodule HelperTest do
  use ExUnit.Case, async: true

  import Cog.Helpers, only: [ensure_integer: 1, get_number: 1]

  test "ensure_integer should return an integer if an integer is passed" do
    assert ensure_integer(5) == 5
  end

  test "ensure_integer should return an integer if a binary is passed" do
    assert ensure_integer("5") == 5
  end

  test "get_number should return an integer if an integer is passed" do
    assert get_number(5) == 5
  end

  test "get_number should return a float if a binary is passed" do
    assert get_number("-5") == -5.0
  end

  test "get_number should return an error if a non-number is passed" do
    assert get_number("hola") == "hola is not a number"
  end
end
