defmodule Cog.Commands.Table do
  use Spanner.GenCommand.Base, bundle: Cog.embedded_bundle, enforcing: false
  alias Cog.Formatters

  @moduledoc """
  Converts lists of maps into a table of columns specified.

  ## Example

      @bot #{Cog.embedded_bundle}:stackoverflow vim | #{Cog.embedded_bundle}:table —fields="title, score" $items
      > title                                             score
      > What is your most productive shortcut with Vim?   1129
      > Vim clear last search highlighting                843
      > How to replace a character for a newline in Vim?  920

  """

  option "fields", type: "string", required: false

  def handle_message(req, state) do
    fields = req.options["fields"]
    |> String.strip(?")
    |> String.split(~r/[\,\s]/, trim: true)

    rows = for row <- hd(req.args) do
      for field <- fields do
        row
        |> Map.get(field, "")
        |> to_string
      end
    end

    response = [fields|rows]
    |> Formatters.Table.format
    |> Formatters.Monospace.format

    {:reply, req.reply_to, response, state}
  end
end
