defmodule Cog.Commands.Rule.Create do
  alias Cog.Repository.Rules
  require Cog.Commands.Helpers, as: Helpers

  Helpers.usage """
  Create a rule by specifying the entire rule or by using the shorthand for a
  command and permission.

  USAGE
    rule create <rule>
    rule create <command> <permission>

  ARGS
    rule        Entire rule to create
    command     Command used to create a rule (used with permission)
    permission  Permission used to create a rule (used with command)

  EXAMPLES
    rule create "when command is s3:delete with arg[0] == 'all' must have site:admin"
    rule create s3:delete site:admin
  """

  def create(%{options: %{"help" => true}}, _args),
    do: show_usage
  def create(_req, [command, permission]),
    do: do_create("when command is '#{command}' must have '#{permission}'")
  def create(_req, [rule]),
    do: do_create(rule)
  def create(_req, _args),
    do: {:error, {:invalid_args, 1, 2}}

  defp do_create(rule) do
    case Rules.ingest(rule) do
      {:ok, rule} ->
        {:ok, "rule-create", rule}
      {:error, error} ->
        {:error, {:rule_invalid, error}}
    end
  end
end
