defmodule Cog.Formatters.Table do

  @moduledoc """
  Generates a list of strings formatted to be easily inserted into a table.
  """

  @doc """
  format/2

  `data` - a list of rows(lists) that will populate the table.
  """
  def format(data) do
    data
    |> transpose
    |> Enum.map(&align_column(&1))
    |> transpose
  end

  defp align_column(column) do
    # First we convert all values in the column to strings
    string_column = Enum.map(column, &cell_string/1)
    # Next we get the longest string from the column and set that to the max width
    max = max_length(string_column)
    # Last we align the column
    Enum.map(string_column, &String.ljust(&1, max))
  end

  defp max_length(column) do
    column
    |> Enum.map(&String.length/1)
    |> Enum.max
  end

  defp transpose(data) do
    data
    |> List.zip
    |> Enum.map(&Tuple.to_list/1)
  end

  defp cell_string(cell) when is_binary(cell),
    do: cell
  defp cell_string(cell) when is_integer(cell),
    do: Integer.to_string(cell)
  defp cell_string(cell) when is_float(cell),
    do: Float.to_string(cell, [decimal: 10, compact: true])
  defp cell_string(cell) when is_list(cell),
    do: Enum.join(cell, ", ")
  defp cell_string(cell) when is_map(cell) do
    string = Enum.map_join(cell, ", ", fn({k, v}) ->
      "#{k}: #{cell_string(v)}"
    end)
    "{ #{string} }"
  end

end
