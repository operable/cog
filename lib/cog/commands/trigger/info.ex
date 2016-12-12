defmodule Cog.Commands.Trigger.Info do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "trigger-info"

  require Cog.Commands.Helpers, as: Helpers
  alias Cog.Repository.Triggers
  require Logger

  @description "Get detailed information about a trigger."

  @arguments "<name>"

  permission "manage_triggers"

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:trigger-info must have #{Cog.Util.Misc.embedded_bundle}:manage_triggers"

  def handle_message(req, state) do
    result = with {:ok, [name]} <- Helpers.get_args(req.args, 1) do
      case Triggers.by_name(name) do
        {:ok, trigger} ->
          {:ok, trigger}
        {:error, :not_found} ->
          {:error, {:resource_not_found, "trigger", name}}
      end
    end

    case result do
      {:ok, data} ->
        {:reply, req.reply_to, "trigger-info", Cog.Command.Trigger.Helpers.convert(data), state}
      {:error, error} ->
        {:error, req.reply_to, Helpers.error(error), state}
    end
  end

end
