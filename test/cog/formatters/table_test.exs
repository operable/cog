defmodule Cog.Formatters.TableTest do
  use ExUnit.Case, async: true

  alias Cog.Formatters.Table

  test "formatting tabular data" do
    data = [["FIRST", "LAST", "AGE"],
            ["Morty", "Smith", "14"],
            ["Summer", "Smith", "17"],
            ["Rick", "Sanchez", "too old"]]

    assert Table.format(data) == [["FIRST ","LAST   ","AGE    "],
                                  ["Morty ","Smith  ","14     "],
                                  ["Summer","Smith  ","17     "],
                                  ["Rick  ","Sanchez","too old"]]
  end
end
