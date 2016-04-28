defmodule Cog.Commands.Min do
  @moduledoc """
  This command allows the user to determine the minimum value given a
  list of inputs.

  Examples:
  > @bot operable:min 49 9 2 2
  > @bot operable:min 0.48 0.2 1.8 3548.4 0.078
  > @bot operable:min "apple" "ball" "car" "zebra"
  """
  use Cog.Command.GenCommand.Base, bundle: Cog.embedded_bundle, enforcing: false
  require Logger

  def handle_message(req, state) do
    min_val = Enum.min(req.args)
    {:reply, req.reply_to, %{min: min_val}, state}
  end

end
