defmodule Cog.Commands.Trigger.List do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "trigger-list"

  alias Cog.Repository.Triggers

  @description "List all triggers."

  @output_description "Returns a list of triggers."

  @output_example """
  [
    {
      "timeout_sec": 30,
      "pipeline": "echo fobar",
      "name": "foo",
      "invocation_url": "http://localhost:4001/v1/triggers/00000000-0000-0000-0000-000000000000",
      "id": "00000000-0000-0000-0000-000000000000",
      "enabled": false,
      "description": null,
      "as_user": null
    }
  ]
  """

  permission "manage_triggers"

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:trigger-list must have #{Cog.Util.Misc.embedded_bundle}:manage_triggers"

  def handle_message(req, state),
    do: {:reply, req.reply_to, "trigger-list", Cog.Command.Trigger.Helpers.convert(Triggers.all), state}

end
