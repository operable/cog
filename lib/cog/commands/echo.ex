defmodule Cog.Commands.Echo do
  use Spanner.GenCommand.Base, bundle: Cog.embedded_bundle, enforcing: false

  @moduledoc """
  Repeats whatever it is passed.

  ## Example

      @bot #{Cog.embedded_bundle}:echo this is nifty
      > this if nifty

  """

  def handle_message(req, state),
    do: {:reply, req.reply_to, Enum.join(req.args, " "), state}

end
