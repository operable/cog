defmodule Cog.Commands.Thorn do
  @moduledoc """
  This command replaces `Th` following a word boundary with þ

  Examples:
  > @bot operable:thorn foo-Thbar-Thbaz
  """
  use Cog.Command.GenCommand.Base, bundle: Cog.embedded_bundle

  rule "when command is #{Cog.embedded_bundle}:thorn allow"

  @upcase_thorn "Þ"
  @downcase_thorn "þ"

  def handle_message(req, state) do
    text = Enum.join(req.args, " ")
    |> String.replace(~r{\bTh}, @upcase_thorn)
    |> String.replace(~r{\bth}, @downcase_thorn)

    {:reply, req.reply_to, text, state}
  end
end
