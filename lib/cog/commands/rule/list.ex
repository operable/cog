defmodule Cog.Commands.Rule.List do
  @moduledoc """
  List all rules or rules for the provided command.

  USAGE
    rule list [FLAGS] [OPTIONS]

  FLAGS
    -h, --help  Display this usage info

  OPTIONS
    -c, --command  List rules belonging to command
  """

  alias Cog.Models.Command
  alias Cog.Models.Rule
  alias Cog.Repo

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

  defp show_usage(error \\ nil) do
    {:ok, "usage", %{usage: @moduledoc, error: error}}
  end
end
