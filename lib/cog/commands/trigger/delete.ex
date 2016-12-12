defmodule Cog.Commands.Trigger.Delete do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "trigger-delete"

  alias Cog.Repository.Triggers
  require Cog.Commands.Helpers, as: Helpers

  @description "Delete triggers by name."

  @arguments "<name...>"

  @examples """
  trigger:delete foo bar baz
  """

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:trigger-delete must have #{Cog.Util.Misc.embedded_bundle}:manage_triggers"

  def handle_message(req, state) do
    result = with {:ok, names} <- Helpers.get_args(req.args, min: 1) do
      {_count, deleted_triggers} = Triggers.delete(names)
      {:ok, "trigger-delete", deleted_triggers}
    end

    case result do
      {:ok, data} ->
        {:reply, req.reply_to, "trigger-delete", Cog.Command.Trigger.Helpers.convert(data), state}
      {:error, error} ->
        {:error, req.reply_to, Helpers.error(error), state}
    end
  end
end
