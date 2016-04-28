defmodule Cog.Commands.Max do
  @moduledoc """
  This command allows the user to determine the maximum value given a
  list of inputs.

  Examples:
  > @bot operable:max 49 9 2 2
  > @bot operable:max 0.48 0.2 1.8 3548.4 0.078
  > @bot operable:max "apple" "ball" "car" "zebra"
  """
  use Cog.Command.GenCommand.Base, bundle: Cog.embedded_bundle, enforcing: false
  require Logger

  def handle_message(req, state) do
    max_val = Enum.max(req.args)
    {:reply, req.reply_to, %{max: max_val}, state}
  end

end
