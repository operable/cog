defmodule HelperTest do
  use ExUnit.Case, async: true

  import Cog.Helpers, only: [ensure_integer: 1]

  test "ensure_integer should return an integer if an integer is passed" do
    assert ensure_integer(5) == 5
  end

  test "ensure_integer should return an integer if a binary is passed" do
    assert ensure_integer("5") == 5
  end

end
