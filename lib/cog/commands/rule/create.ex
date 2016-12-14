defmodule Cog.Commands.Rule.Create do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "rule-create"

  alias Cog.Commands.Rule
  alias Cog.Repository.Rules

  @description "Create a rule."

  @long_description "Create a rule by specifying the entire rule or by using the shorthand for a command and permission."

  @arguments "[<rule> | <command> <permission>]"

  @examples """
  rule create "when command is s3:delete with arg[0] == 'all' must have site:admin"
  rule create s3:delete site:admin
  """

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

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:rule-create must have #{Cog.Util.Misc.embedded_bundle}:manage_commands"

  def handle_message(req, state) do
    case create(req.args) do
      {:ok, rule} ->
        {:reply, req.reply_to, "rule-create", rule, state}
      {:error, error} ->
        {:error, req.reply_to, Rule.error(error), state}
    end
  end

  defp create([command, permission]),
    do: do_create("when command is '#{command}' must have '#{permission}'")
  defp create([rule]),
    do: do_create(rule)
  defp create(_args),
    do: {:error, {:invalid_args, 1, 2}}

  defp do_create(rule) do
    case Rules.ingest(rule) do
      {:ok, rule} ->
        {:ok, rule}
      {:error, error} ->
        {:error, {:rule_invalid, error}}
    end
  end
end
