defmodule Cog.Formatters.Table do
  def format(data) do
    data = Enum.map(data, fn row ->
      Enum.map(row, &to_string/1)
    end)

    data
    |> format_columns
    |> format_rows
  end

  defp format_columns(data) do
    data
    |> transpose
    |> Enum.map(&pad_column/1)
    |> transpose
  end

  defp format_rows(data) do
    data
    |> Enum.map(&Enum.join(&1, "  "))
    |> Enum.map(&String.rstrip/1)
    |> Enum.join("\n")
  end

  defp pad_column(column) do
    max = max_length(column)
    Enum.map(column, &String.ljust(&1, max))
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
end
