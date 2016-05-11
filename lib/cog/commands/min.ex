defmodule Cog.Commands.Min do
  @moduledoc """
  This command allows the user to determine the minimum value given a
  list of inputs. The min value is based on erlangs term ordering.

  USAGE
    min [ARGS ...]

  EXAMPLES
    min 49 9 2 2
    > 2

    min 0.48 0.2 1.8 3548.4 0.078
    > 0.078

    min "apple" "ball" "car" "zebra"
    > apple
  """
  use Cog.Command.GenCommand.Base, bundle: Cog.embedded_bundle
  require Logger

  rule "when command is #{Cog.embedded_bundle}:min allow"

  def handle_message(req, state) do
    min_val = Enum.min(req.args)
    {:reply, req.reply_to, %{min: min_val}, state}
  end

end
