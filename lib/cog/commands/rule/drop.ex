defmodule Cog.Commands.Rule.Drop do
  alias Cog.Repository.Rules
  require Cog.Commands.Helpers, as: Helpers

  Helpers.usage """
  Drops rules by id.

  USAGE
    rule drop [FLAGS] <id...>

  ARGS
    id  Specifies the rule to drop

  FLAGS
    -h, --help  Display this usage info

  """

  def drop(%{options: %{"help" => true}}, _args) do
    show_usage
  end

  def drop(_req, []) do
    {:error, {:under_min_args, 1}}
  end

  def drop(_req, args) do
    with {:ok, uuids} <- validate_uuids(args),
         {:ok, rules} <- find_rules(uuids),
         delete_rules(rules),
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
