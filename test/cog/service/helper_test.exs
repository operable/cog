defmodule Cog.Service.HelperTest do
  use ExUnit.Case, async: true

  import Cog.Service.Helper

  test "converting a list to a map" do
    assert %{this: "is", a: "test"} = format_entries([this: "is", a: "test"])
  end

  test "converting a list of lists to a list of maps" do
    assert [%{this: "is"}, %{a: "test", of: "lists"}] = format_entries([[this: "is"], [a: "test", of: "lists"]])
  end

  test "converting a list of char lists to a map of strings" do
    assert %{"this" => "is", "a" => "test"} = format_entries([{'this', 'is'}, {'a', 'test'}])
  end

  test "formating a timestamp" do
    assert "2016-01-05 14:30:42" = format_entries({{2016, 1, 5}, {14, 30, 42}})
  end
end
