defmodule Cog.Commands.Echo do
  use Cog.Command.GenCommand.Base, bundle: Cog.embedded_bundle

  @moduledoc """
  Repeats whatever it is passed.

  ## Example

      @bot #{Cog.embedded_bundle}:echo this is nifty
      > this if nifty

  """

  rule "when command is #{Cog.embedded_bundle}:echo allow"

  def handle_message(req, state),
    do: {:reply, req.reply_to, Enum.join(req.args, " "), state}

end
