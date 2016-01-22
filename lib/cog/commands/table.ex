defmodule Cog.Commands.Table do
  use Spanner.GenCommand.Base, bundle: Cog.embedded_bundle, enforcing: false, execution: :once, calling_convention: :all

  @moduledoc """
  Converts lists of maps into a table of columns specified.

  ## Example

      @bot #{Cog.embedded_bundle}:stackoverflow vim | #{Cog.embedded_bundle}:table —fields="title, score" $items
      > title                                             score
      > What is your most productive shortcut with Vim?   1129
      > Vim clear last search highlighting                843
      > How to replace a character for a newline in Vim?  920

  """

  option "fields", type: "string", required: true

  @cell_padding 2

  def handle_message(req, state) do
    headers = hd(req.options)
    |> Map.get("fields")
    |> String.strip(?")
    |> String.split(~r/[\,\s]/, trim: true)

    rows = Enum.map(req.cog_env, &(pluck(&1, headers)))
    aligned_rows = align_rows([headers|rows])

    {:reply, req.reply_to, "table", %{"rows" => aligned_rows}, state}
  end

  defp pluck(item, fields) do
    {new_item, _} = Map.split(item, fields)
    Enum.map(fields, &(Map.get(new_item, &1)))
  end

  defp align_rows(rows) do
    spacings = Enum.reduce(rows, hd(rows), fn(row, acc) ->
      Enum.zip(row, acc)
      |> Enum.map(&max_cell/1)
    end)
    |> Enum.map(&String.length/1)

    Enum.map(rows, fn(row) ->
      Enum.zip(row, spacings)
      |> Enum.map(&align(&1, @cell_padding))
    end)
  end

  # Left aligns the cell
  defp align({cell, spacing}, padding),
    do: String.ljust(cell, spacing + padding)

  # Returns the longest cell
  defp max_cell({cell1, cell2}) do
    Enum.max_by([cell1, cell2], &String.length/1)
  end

end
