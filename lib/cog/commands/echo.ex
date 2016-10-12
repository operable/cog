defmodule Cog.Commands.Echo do
  use Cog.Command.GenCommand.Base, bundle: Cog.Util.Misc.embedded_bundle

  @description "Repeats whatever it is passed"
  @arguments "[args ...]"
  @examples "echo \"this is nifty\""

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:echo allow"

  def handle_message(req, state),
    do: {:reply, req.reply_to, Enum.map_join(req.args, " ", &serialize/1), state}

  # We should only have to worry about maps and lists here. Anything else
  # we might get should implement 'to_string'.
  defp serialize(val) when is_map(val) or is_list(val),
    do: Poison.encode!(val)
  defp serialize(val),
    do: to_string(val)

end
