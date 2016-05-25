defmodule Cog.Commands.Rule.List do
  alias Cog.Repository.Rules
  require Cog.Commands.Helpers, as: Helpers

  Helpers.usage """
  List all rules or rules for the provided command.

  USAGE
    rule list [FLAGS] [OPTIONS]

  FLAGS
    -h, --help  Display this usage info

  OPTIONS
    -c, --command  List rules belonging to command
  """

  def list(%{options: %{"help" => true}}, _args) do
    show_usage
  end

  def list(%{options: %{"command" => command}}, _args) do
    case Rules.rules_for_command(command) do
      {:ok, rules} ->
        {:ok, "rule-list", rules}
      error ->
        error
    end
  end

  def list(_req, _args) do
    {:ok, "rule-list", Rules.all_rules}
  end
end
