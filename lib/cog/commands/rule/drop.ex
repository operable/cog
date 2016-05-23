defmodule Cog.Commands.Rule.Drop do
  use Cog.Queries
  alias Cog.Models.Command
  alias Cog.Models.Rule
  alias Cog.Repo
  require Cog.Commands.Helpers, as: Helpers

  Helpers.usage """
  Drops rules by id or all rules for a specific command.

  USAGE
    rule drop [FLAGS] [OPTIONS] <id...>

  ARGS
    id  Specifies the rule to drop

  FLAGS
    -h, --help  Display this usage info

  OPTIONS
    -c, --command  Drops rules belonging to the command
  """

  def drop(%{options: %{"help" => true}}, _args) do
    show_usage
  end

  def drop(%{options: %{"command" => command}}, _args) do
    case Command.parse_name(command) do
      {:ok, command} ->
        query = Ecto.assoc(command, :rules)
        rules = Repo.all(query)
        Repo.delete_all(query)
        {:ok, "rule-drop", rules}
      error ->
        error
    end
  end

  def drop(_req, []) do
    {:error, {:under_min_args, 1}}
  end

  def drop(_req, args) do
    with {:ok, uuids} <- validate_uuids(args),
         {:ok, rules} <- find_rules(uuids),
         delete_rules(uuids),
         do: {:ok, "rule-drop", rules}
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
    case Repo.all(rule_query(uuids)) do
      [] ->
        {:error, {:rule_not_found, uuids}}
      rules ->
        {:ok, rules}
    end
  end

  defp delete_rules(uuids),
    do: Repo.delete_all(rule_query(uuids))

  defp rule_query(uuids),
    do: from r in Rule, where: r.id in ^uuids
end
