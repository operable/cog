defmodule Cog.Commands.Rule.Create do
  @moduledoc """
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

  alias Cog.Models.Rule
  alias Cog.RuleIngestion
  alias Piper.Permissions.Parser

  def create(%{options: %{"help" => true}}, _args),
    do: show_usage
  def create(_req, [command, permission]),
    do: do_create("when command is '#{command}' must have '#{permission}'")
  def create(_req, [rule]),
    do: do_create(rule)
  def create(_req, _args),
    do: {:error, {:invalid_args, 1, 2}}

  defp do_create(rule) do
    with :ok <- validate_permissions(rule),
         {:ok, rule} <- create_rule(rule),
         do: {:ok, rule}
  end

  defp show_usage(error \\ nil),
    do: {:ok, "usage", %{usage: @moduledoc, error: error}}

  defp validate_permissions(rule) do
    case Parser.parse(rule) do
      {:ok, _ast, permissions} ->
        Enum.reduce_while(permissions, :ok, fn permission, :ok ->
          case Rule.parse_name(permission) do
            {:ok, {"site", _permission}} ->
              {:cont, :ok}
            {:ok, {_non_site_namesapce, _permission}} ->
              {:halt, {:error, :rule_non_site_namespace}}
            {:error, error} ->
              {:halt, {:error, error}}
          end
        end)
      {:error, error} ->
        {:error, {:rule_invalid, error}}
    end
  end

  defp create_rule(rule) do
    case RuleIngestion.ingest(rule) do
      {:ok, rule} ->
        {:ok, "rule-create", rule}
      {:error, error} ->
        {:error, {:rule_invalid, error}}
    end
  end
end
