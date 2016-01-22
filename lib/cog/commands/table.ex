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

    rows = Enum.map(req.cog_env, &(get_row(&1, headers)))
    aligned_rows = Cog.Formatters.Table.format([headers|rows], @cell_padding)

    {:reply, req.reply_to, "table", %{"rows" => aligned_rows}, state}
  end

  defp get_row(item, fields) do
    new_item = Map.take(item, fields)
    Enum.map(fields, &(Map.get(new_item, &1)))
  end

end
