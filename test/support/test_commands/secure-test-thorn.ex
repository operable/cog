defmodule Cog.Commands.SecureTestThorn do
  use Cog.Command.GenCommand.Base, bundle: Cog.embedded_bundle, name: "st-thorn"

  @upcase_thorn "Þ"
  @downcase_thorn "þ"

  permission "st-thorn"
  rule "when command is #{Cog.embedded_bundle}:st-thorn must have #{Cog.embedded_bundle}:st-thorn"

  def handle_message(req, state) do
    text = Enum.join(req.args, " ")
    |> String.replace(~r{\bTh}, @upcase_thorn)
    |> String.replace(~r{\bth}, @downcase_thorn)

    {:reply, req.reply_to, text, state}
  end
end
