defmodule Cog.Commands.Trigger.Enable do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "trigger-enable"

  alias Cog.Commands.Helpers
  alias Cog.Commands.Trigger

  @description "Enable a pipeline trigger. Provided as a convenient alternative to `trigger update <trigger-name> --enabled=true`."

  @arguments "<name>"

  @examples """
  trigger enable my-trigger
  """

  @output_description "Returns the json representation for the enabled trigger."

  @output_example """
  [
    {
      "timeout_sec": 30,
      "pipeline": "echo fobar",
      "name": "foo",
      "invocation_url": "http://localhost:4001/v1/triggers/00000000-0000-0000-0000-000000000000",
      "id": "00000000-0000-0000-0000-000000000000",
      "enabled": true,
      "description": null,
      "as_user": null
    }
  ]
  """

  permission "manage_triggers"

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:trigger-enable must have #{Cog.Util.Misc.embedded_bundle}:manage_triggers"

  def handle_message(req, state) do
    result = with {:ok, [name]} <- Helpers.get_args(req.args, 1) do
      options = %{"enabled" => true}
      req = %{req | options: options}
      case Cog.Commands.Trigger.Update.update(req, [name]) do
        {:ok, _, data} ->
          {:ok, data}
        other ->
          other
      end
    end

    case result do
      {:ok, data} ->
        {:reply, req.reply_to, "trigger-enable", Cog.Command.Trigger.Helpers.convert(data), state}
      {:error, error} ->
        {:error, req.reply_to, Trigger.error(error), state}
    end
  end

end
