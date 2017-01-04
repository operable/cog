defmodule Cog.Commands.Rule.Info do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "rule-info"

  alias Cog.Commands.Rule, as: RuleCommand
  alias Cog.Models.Rule
  alias Cog.Repository.Rules

  @description "Display a specific rule by ID."

  @arguments "<id>"

  @output_description "Returns the rule, id and command the rule applies to."

  @output_example """
  [
    {
      "rule": "when command is operable:min allow",
      "id": "00000000-0000-0000-0000-000000000000",
      "command": "operable:min"
    }
  ]
  """

  permission "manage_commands"

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:rule-info must have #{Cog.Util.Misc.embedded_bundle}:manage_commands"

  def handle_message(req, state) do
    case info(req) do
      {:ok, rule} ->
        {:reply, req.reply_to, "rule-info", rule, state}
      {:error, error} ->
        {:error, req.reply_to, RuleCommand.error(error), state}
    end
  end

  defp info(%{args: [id]}) when is_binary(id) do
    if Cog.UUID.is_uuid?(id) do
      case Rules.rule(id) do
        %Rule{}=rule ->
          {:ok, rule}
        nil ->
          {:error, {:resource_not_found, "rule", id}}
      end
    else
      {:error, {:rule_uuid_invalid, id}}
    end
  end
  defp info(%{args: [_]}),
    do: {:error, :wrong_type}
  defp info(%{args: []}),
    do: {:error, {:not_enough_args, 1}}
  defp info(_req),
    do: {:error, {:too_many_args, 1}}

end
