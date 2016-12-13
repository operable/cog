defmodule Cog.Commands.Trigger.Disable do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "trigger-disable"

  require Cog.Commands.Helpers, as: Helpers

  @description "Disable a pipeline trigger. Provided as a convenient alternative to `trigger update <trigger-name> --enabled=false`."

  @arguments "<name>"

  @examples """
  trigger disable my-trigger
  """

  @output_description "Returns the json representation for the disabled trigger."

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

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:trigger-disable must have #{Cog.Util.Misc.embedded_bundle}:manage_triggers"

  def handle_message(req, state) do
    result = with {:ok, [name]} <- Helpers.get_args(req.args, 1) do
      options = %{"enabled" => false}
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
        {:reply, req.reply_to, "trigger-disable", Cog.Command.Trigger.Helpers.convert(data), state}
      {:error, error} ->
        {:error, req.reply_to, Helpers.error(error), state}
    end
  end

end
