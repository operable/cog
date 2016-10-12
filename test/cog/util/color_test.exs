defmodule Util.ColorsTest do

  @colors_file "css-color-names.json"

  use ExUnit.Case, async: true

  alias Cog.Util.Colors

  test "look up hex code by name" do
    assert Colors.name_to_hex("lightblue") == "#add8e6"
  end

  test "look up name by hex code" do
    assert Colors.hex_to_name("#add8e6") == "lightblue"
  end

  test "hex codes are passed thru" do
    assert Colors.name_to_hex("#add8e6") == "#add8e6"
  end

  test "unknown name returns :unknown_color" do
    assert Colors.name_to_hex("superultramarine") == :unknown_color
  end

  test "unknown hex code returns :unknown_color" do
    assert Colors.hex_to_name("#add8e0") == :unknown_color
  end

  test "accurate code is generated from JSON file" do
    hex_codes = File.read!(Path.join(String.Chars.to_string(:code.priv_dir(:cog)), @colors_file)) |> Poison.decode!
    names = Enum.reduce(hex_codes, %{}, fn({name, code}, acc) -> Map.put(acc, code, name) end)
    Enum.each(hex_codes, fn({name, code}) ->
      assert Colors.name_to_hex(name) == code
      assert Colors.hex_to_name(code) == Map.get(names, code)
    end)
    assert Colors.names() == Enum.sort(Map.keys(hex_codes))
  end

end
