defmodule Cog.Commands.Rule.List do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "rule-list"

  alias Cog.Commands.Rule
  alias Cog.Repository.Rules

  @description "List all rules or rules for the provided command"

  @arguments "[command]"

  @output_description "Returns the list of rules."

  @output_example """
  [
    {
      "rule": "when command is operable:min allow",
      "id": "00000000-0000-0000-0000-000000000000",
      "command": "operable:min"
    },
    {
      "rule": "when command is operable:max allow",
      "id": "00000000-0000-0000-0000-000000000000",
      "command": "operable:max"
    }
  ]
  """

  permission "manage_commands"

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:rule-list must have #{Cog.Util.Misc.embedded_bundle}:manage_commands"

  def handle_message(req = %{args: args}, state) do
    case list(args) do
      {:ok, rules} ->
        {:reply, req.reply_to, "rule-list", rules, state}
      {:error, error} ->
        {:error, req.reply_to, Rule.error(error), state}
    end
  end

  defp list([command]),
    do: Rules.rules_for_command(command)
  defp list(_req),
    do: {:ok, Rules.all_rules}
end
