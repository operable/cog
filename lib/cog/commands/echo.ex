defmodule Cog.Commands.Echo do
  use Cog.Command.GenCommand.Base, bundle: Cog.Util.Misc.embedded_bundle

  @description "Repeats whatever it is passed"
  @arguments "[args ...]"
  @examples "echo \"this is nifty\""

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:echo allow"

  def handle_message(req, state),
    do: {:reply, req.reply_to, Enum.join(req.args, " "), state}
end
