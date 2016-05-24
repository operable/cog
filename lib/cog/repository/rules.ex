defmodule Cog.Repository.Rules do
  alias Cog.Models.{Rule, Command, Permission, Bundle, BundleVersion, JoinTable}
  alias Cog.Queries
  alias Cog.Repo
  alias Cog.Repository.Bundles
  alias Piper.Permissions.{Ast, Parser}

  @doc """
  Parse, validate and store the rule in the database. Ingesting is idempotent.

  Rules are run through a series of validations before being created. First, we
  parse the rule to check its syntax. Then, we check to make sure the
  referenced command and permissions exist and that the permissions belong to
  the same bundle as the command (or the "site" namespace). 

  When creating the rule we also make sure that the permissions have been
  correctly granted and that the rule is associated with the correct bundle
  version.
  """
  def ingest(rule),
    do: ingest(rule, Bundles.site_bundle_version)
  def ingest(rule, bundle_version) do
    Repo.transaction(fn ->
      case do_ingest(rule, bundle_version) do
        {:ok, rule} ->
          rule
        {:error, error} ->
          Repo.rollback(error)
      end
    end)
  end

  def ingest_without_transaction(rule),
    do: ingest(rule, Bundles.site_bundle_version)
  def ingest_without_transaction(rule, bundle_version),
    do: do_ingest(rule, bundle_version)

  defp do_ingest(rule, %BundleVersion{}=bundle_version) when is_binary(rule) do
    with {:ok, ast, permission_names} <- validate_syntax(rule),
         {:ok, command}               <- validate_command(ast),
         {:ok, permissions}           <- validate_permissions(permission_names),
         :ok                          <- validate_matching_permissions(command, permissions),
         do: create_rule(ast, command, permissions, bundle_version)
  end

  defp create_rule(ast, command, permissions, bundle_version) do
    case find_or_create_rule(ast, command) do
      {:ok, rule} ->
        grant_permissions(rule, permissions)
        add_to_bundle_version(rule, bundle_version)
        {:ok, rule}
      {:error, %Ecto.Changeset{}=changeset} ->
        {:error, changeset.errors}
    end
  end

  defp find_or_create_rule(ast, command) do
    parse_tree = Parser.rule_to_json!(ast)
    rule = Repo.get_by(Rule, command_id: command.id, parse_tree: parse_tree)

    case rule do
      nil ->
        Rule.insert_new(command, %{parse_tree: parse_tree, score: ast.score})
      %Rule{}=rule ->
        {:ok, rule}
    end
  end

  defp grant_permissions(rule, permissions) do
    Enum.each(permissions, fn permission ->
      :ok = Permittable.grant_to(rule, permission)
    end)
  end

  defp add_to_bundle_version(rule, bundle_version) do
    JoinTable.associate(rule, bundle_version)
  end

  defp validate_syntax(rule_text) do
    case Parser.parse(rule_text) do
      {:ok, %Ast.Rule{}=ast, permissions} ->
        {:ok, ast, permissions}
      {:error, error} ->
        {:error, {:invalid_rule_syntax, error}}
    end
  end

  defp validate_command(%Ast.Rule{}=ast) do
    name = Ast.Rule.command_name(ast)

    command = name
    |> Queries.Command.named
    |> Repo.one

    case command do
      nil ->
        {:error, {:unrecognized_command, name}}
      %Command{}=command ->
        {:ok, Repo.preload(command, :bundle)}
    end
  end

  defp validate_permissions(permission_names) do
    Enum.reduce_while(permission_names, {:ok, []}, fn permission_name, {:ok, acc} ->
      case validate_permission(permission_name) do
        {:ok, permission} ->
          {:cont, {:ok, [permission|acc]}}
        error ->
          {:halt, error}
      end
    end)
  end

  defp validate_permission(permission_name) do
    permission = permission_name
    |> Queries.Permission.from_full_name
    |> Repo.one

    case permission do
      nil ->
        {:error, {:unrecognized_permission, permission_name}}
      %Permission{}=permission ->
        {:ok, Repo.preload(permission, :bundle)}
    end
  end

  defp validate_matching_permissions(command, permissions) do
    Enum.reduce_while(permissions, :ok, fn permission, :ok ->
      case validate_matching_permission(command, permission) do
        :ok ->
          {:cont, :ok}
        error ->
          {:halt, error}
      end
    end)
  end

  defp validate_matching_permission(_command, %Permission{bundle: %Bundle{name: "site"}}),
    do: :ok
  defp validate_matching_permission(%Command{bundle: %Bundle{name: name}}, %Permission{bundle: %Bundle{name: name}}),
    do: :ok
  defp validate_matching_permission(_command, %Permission{bundle: %Bundle{name: bundle_name}, name: permission_name}),
    do: {:error, {:permission_bundle_mismatch, bundle_name <> ":" <> permission_name}}
end
