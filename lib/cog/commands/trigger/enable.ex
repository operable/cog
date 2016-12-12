defmodule Cog.Commands.Trigger.Enable do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "trigger-enable"

  require Cog.Commands.Helpers, as: Helpers

  @description "Enable a pipeline trigger. Provided as a convenient alternative to `trigger update <trigger-name> --enabled=true`."

  @arguments "<name>"

  @examples """
  trigger enable my-trigger
  """

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
        {:reply, req.reply_to, "trigger-enable", data, state}
      {:error, error} ->
        {:error, req.reply_to, Helpers.error(error), state}
    end
  end

end
