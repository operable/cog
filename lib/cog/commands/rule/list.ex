defmodule Cog.Commands.Rule.List do
  alias Cog.Models.Command
  alias Cog.Models.Rule
  alias Cog.Repo
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
    case Command.parse_name(command) do
      {:ok, command} ->
        {:ok, "rule-list", Repo.all(Ecto.assoc(command, :rules))}
      error ->
        error
    end
  end

  def list(_req, _args) do
    {:ok, "rule-list", Repo.all(Rule)}
  end
end
