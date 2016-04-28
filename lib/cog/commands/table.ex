defmodule Cog.Commands.Table do
  use Cog.Command.GenCommand.Base, bundle: Cog.embedded_bundle, enforcing: false, execution: :once
  alias Cog.Formatters.Table

  @moduledoc """
  Converts lists of maps into a table of columns specified.

  ## Example

      @bot #{Cog.embedded_bundle}:stackoverflow vim | #{Cog.embedded_bundle}:table —fields="title, score" $items
      > title                                             score
      > What is your most productive shortcut with Vim?   1129
      > Vim clear last search highlighting                843
      > How to replace a character for a newline in Vim?  920

  """

  option "fields", type: "list", required: true

  @cell_padding "  "

  def handle_message(req, state) do
    %{"fields" => headers} = req.options
    table = format_table(headers, req.cog_env)
    {:reply, req.reply_to, "table", %{"table" => table}, state}
  end

  defp format_table(headers, rows) do
    rows = Enum.map(rows, fn row ->
      Enum.map(headers, &Map.get(row, &1, ""))
    end)

    [headers|rows]
    |> Table.format
    |> Enum.map_join("\n", &Enum.join(&1, @cell_padding))
  end
end
