defmodule Cog.Commands.Rule.Info do
  alias Cog.Models.Rule
  alias Cog.Repository.Rules
  require Cog.Commands.Helpers, as: Helpers

  Helpers.usage """
  Display a specific rule by ID

  USAGE
    rule info [FLAGS] <id>

  FLAGS
    -h, --help  Display this usage info

  ARGS
    id     The UUID of the rule to show

  """

  def info(%{options: %{"help" => true}}, _args),
    do: show_usage
  def info(_req, [id]) when is_binary(id) do
    if Cog.UUID.is_uuid?(id) do
      case Rules.rule(id) do
        %Rule{}=rule ->
          {:ok, "rule-info",
           Cog.V1.RuleView.render("show.json", %{rule: rule})[:rule]}
        nil ->
          {:error, {:resource_not_found, "rule", id}}
      end
    else
      {:error, {:rule_uuid_invalid, id}}
    end
  end
  def info(_req, [_]),
    do: {:error, :wrong_type}
  def info(_req, []),
    do: {:error, {:not_enough_args, 1}}
  def info(_req, _),
    do: {:error, {:too_many_args, 1}}

end
