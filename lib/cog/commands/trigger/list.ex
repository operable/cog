defmodule Cog.Commands.Trigger.List do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "trigger-list"

  alias Cog.Repository.Triggers

  @description "List all triggers."

  permission "manage_triggers"

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:trigger-list must have #{Cog.Util.Misc.embedded_bundle}:manage_triggers"

  def handle_message(req, state),
    do: {:reply, req.reply_to, "trigger-list", Cog.Command.Trigger.Helpers.convert(Triggers.all), state}

end
