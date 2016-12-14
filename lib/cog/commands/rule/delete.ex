defmodule Cog.Commands.Rule.Delete do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "rule-delete"

  alias Cog.Commands.Rule
  alias Cog.Repository.Rules

  @description "Deletes rules by id."

  @arguments "<id...>"

  @output_description "Returns the rule that was just deleted."

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

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:rule-delete must have #{Cog.Util.Misc.embedded_bundle}:manage_commands"

  def handle_message(%{args: []}, _state),
    do: {:error, {:under_min_args, 1}}
  def handle_message(req, state) do
    result = with {:ok, uuids} <- validate_uuids(req.args),
         {:ok, rules} <- find_rules(uuids),
         delete_rules(rules),
         do: {:ok, rules}

    case result do
      {:ok, rules} ->
        {:reply, req.reply_to, "rule-delete", rules, state}
      {:error, error} ->
        {:error, req.reply_to, Rule.error(error), state}
    end
  end

  defp validate_uuids(uuids) do
    Enum.reduce_while(uuids, {:ok, []}, fn uuid, {:ok, uuids} ->
      case Cog.UUID.is_uuid?(uuid) do
        true ->
          {:cont, {:ok, [uuid|uuids]}}
        false ->
          {:halt, {:error, {:rule_uuid_invalid, uuid}}}
      end
    end)
  end

  defp find_rules(uuids) do
    case Rules.rules(uuids) do
      [] ->
        {:error, {:rule_not_found, uuids}}
      rules ->
        {:ok, rules}
    end
  end

  defp delete_rules(rules),
    do: Enum.each(rules, &Rules.delete_or_disable/1)

end
