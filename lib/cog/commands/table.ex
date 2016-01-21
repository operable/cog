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

  def handle_message(req, state) do
    headers = hd(req.options)
    |> Map.get("fields")
    |> String.strip(?")
    |> String.split(~r/[\,\s]/, trim: true)

    rows = Enum.map(req.cog_env, &(pluck(&1, headers)))

    rows = [headers|rows]
    padded_rows = cell_lengths(rows)
    |> Enum.reduce([], &biggest/2)
    |> pad_rows(padding, rows)

    {:reply, req.reply_to, "table", %{"rows" => padded_rows}, state}
  end

  defp pluck(item, fields) do
    {new_item, _} = Map.split(item, fields)
    Enum.map(fields, &(Map.get(new_item, &1)))
  end

  defp pad_rows(padding, rows) do
    Enum.map(rows, fn(row) ->
      pad(row, padding)
    end)
  end

  defp pad(row, padding) do
    pad(row, padding, [])
  end

  defp pad([cell | r], [p1 | prest], acc) do
    pad(r, prest, [String.ljust(cell, p1 + 3) | acc])
  end
  defp pad([], [], acc) do
    Enum.reverse(acc)
  end

  defp cell_lengths(rows) do
    Enum.map(rows, fn(row) ->
      Enum.map(row, &String.length/1)
    end)
  end

  defp biggest(row, []) do
    row
  end
  defp biggest(row1, row2) do
    biggest(row1, row2, [])
  end

  defp biggest([l1 | r1], [l2 | r2], acc) do
    biggest(r1, r2, [Enum.max([l1, l2]) | acc])
  end
  defp biggest([], [], acc) do
    Enum.reverse(acc)
  end

end
