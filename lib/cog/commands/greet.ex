defmodule Cog.Commands.Greet do
  use Cog.Command.GenCommand.Base, bundle: Cog.embedded_bundle

  @moduledoc """
  Introduce the bot to new coworkers!

  ## Example

      @bot #{Cog.embedded_bundle}:greet @new_hire
      > Hello @new_hire
      > I'm Cog! I can do lots of things ...

  """

  rule "when command is #{Cog.embedded_bundle}:greet allow"

  def handle_message(req, state) do
    {:reply, req.reply_to, "greet", %{greetee: List.first(req.args)}, state}
  end
end
