defmodule Cog.Commands.Max do
  @moduledoc """
  This command allows the user to determine the maximum value given a
  list of inputs. The max value is based on erlangs term ordering.

  USAGE
    max [ARGS ...]

  EXAMPLES
    max 49 9 2 2
    > 49

    max 0.48 0.2 1.8 3548.4 0.078
    > 3548.4

    max "apple" "ball" "car" "zebra"
    > zebra
  """
  use Cog.Command.GenCommand.Base, bundle: Cog.embedded_bundle
  require Logger

  rule "when command is #{Cog.embedded_bundle}:max allow"

  def handle_message(req, state) do
    max_val = Enum.max(req.args)
    {:reply, req.reply_to, %{max: max_val}, state}
  end

end
