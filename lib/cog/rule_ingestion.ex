defmodule Cog.RuleIngestion do

  defstruct rule_text: nil, expr: nil, command: nil, permissions: nil, all_permissions: [], errors: []

  alias Piper.Permissions.Parser
  alias Piper.Permissions.Ast
  alias Cog.Models.Rule
  alias Cog.Models.Permission
  alias Cog.Queries
  alias Cog.Repo

  @doc """
  Take the text of a rule and store it in the database as a Rule model.

  A number of validations are carried out prior to this,
  however. Should any of them fail, error tuples are accumulated as
  far as the processing can continue. For example, if the rule text is
  syntactically invalid, we won't go on to check that the command
  mentioned actually exists. On the other hand, if a rule *is* valid,
  we can try and verify the commands and permissions mentioned all
  exist.

  If all validations succeed, we can insert the rule in the database,
  as well as relationally link the mentioned permissions to the rule
  (transactionally, of course).

  Returns `{:ok, Rule}` or an error tuple with a list of all errors
  encountered in processing.
  """
  def ingest(rule_text, start_txn \\ true)
  def ingest(rule_text, true) do
    Repo.transaction(fn() ->
      ingest(rule_text, false)
    end)
  end
  def ingest(rule_text, false) do
    case %__MODULE__{rule_text: rule_text}
      |> validate_rule_text
      |> validate_command
      |> validate_permissions
      |> ingest_rule do
        {:ok, rule} ->
          rule
        {:error, errors} ->
          Repo.rollback(errors)
      end
  end

  # Ensure that the given rule text is syntactically valid. If it is, a
  # `Piper.Permissions.Ast.Rule` is generated from it; otherwise, an error is
  # collected, providing context on where the parsing failed.
  def validate_rule_text(%__MODULE__{rule_text: rule_text, errors: errors}=input) do
    case Parser.parse(rule_text) do
      {:ok, %Ast.Rule{}=expr, permissions} ->
        %__MODULE__{input | expr: expr, all_permissions: permissions}
      {:error, error} ->
        %__MODULE__{input | errors: errors ++ [{:invalid_rule_syntax, error}]}
    end
  end

  # Ensure that the command mentioned in the valid rule exists within
  # the database. If it does, a `Command` model is collected for future
  # use. If not, an error is collected.
  #
  # If a valid `Piper.Permissions.Ast.Rule` does not exist for the rule text, then we
  # don't have a valid rule, and this function becomes a no-op.
  def validate_command(%__MODULE__{expr: %Ast.Rule{}=rule, errors: errors}=input) do
    name = Ast.Rule.command_name(rule)
    case name |> Queries.Command.named |> Repo.one do
      %Cog.Models.Command{}=cmd ->
        %__MODULE__{input | command: cmd}
      nil ->
        %__MODULE__{input | errors: errors ++ [{:unrecognized_command, name}]}
    end
  end
  def validate_command(%__MODULE__{expr: nil}=input),
    do: input

  # Ensure that all permissions mentioned in a syntactically-valid rule
  # exist in the database. For each permission that exists, a
  # `Permission` model is accumulated. For each that is missing, an
  # error is accumulated.
  #
  # As with `validate_command/1`, if we do not have a valid rule, this
  # function becomes a no-op.
  def validate_permissions(%__MODULE__{all_permissions: permission_names,
                                        errors: errors}=input) do
    grouped = permission_names
    |> Enum.map(fn(name) ->
      case name |> Cog.Queries.Permission.from_full_name |> Repo.one do
        %Permission{}=p -> p
        nil -> {:unrecognized_permission, name}
      end
    end)
    |> Enum.group_by(fn
      (%Permission{}) -> :permission
      (_) -> :error
    end)

    %__MODULE__{input | permissions: Map.get(grouped, :permission),
                errors: errors ++ Map.get(grouped, :error, [])}
  end
  def validate_permissions(input),
    do: input

  # Here's where the magic happens!
  #
  # When processing gets this far, we can be assured that we've got a
  # valid rule, the command and permissions all exist, and we can
  # proceed with the insertion into the database.
  #
  # If we have any errors, on the other hand, we don't bother with the
  # database calls, and just return all the errors.
  def ingest_rule(%__MODULE__{expr: %Ast.Rule{}=expr,
                              command: command,
                              permissions: permissions,
                              errors: []}) do
    case Rule.insert_new(command, %{parse_tree: Parser.rule_to_json!(expr),
                                    score: expr.score}) do
      {:ok, rule} ->
        Enum.each(permissions, fn(p) ->
          :ok = Permittable.grant_to(rule, p)
        end)
        {:ok, rule}
      {:error, %Ecto.Changeset{}=changeset} ->
        {:error, changeset.errors}
    end
  end
  def ingest_rule(%__MODULE__{errors: errors}),
    do: {:error, errors}

end
