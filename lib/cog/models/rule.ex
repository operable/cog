defmodule Cog.Models.Rule do
 use Cog.Model
 alias Ecto.Changeset
 alias Cog.Models.Command
 alias Piper.Permissions.Ast
 alias Piper.Permissions.Parser

  schema "rules" do
   field :parse_tree, :map
   field :score, :integer
   field :enabled, :boolean, default: true

   belongs_to :command, Cog.Models.Command

   has_many :permission_grants, Cog.Models.RulePermission
   has_many :permissions, through: [:permission_grants, :permission]

   has_many :bundle_version_registration, Cog.Models.RuleBundleVersion
   has_many :bundle_versions, through: [:bundle_version_registration, :bundle_version]

   timestamps
  end

  @required_fields ~w(parse_tree score)
  @optional_fields ~w(enabled)

  summary_fields [:id, :score, :parse_tree]
  detail_fields [:id, :score, :parse_tree]

  def insert_new(%Command{}=command, %Ast.Rule{}=rule) do
    insert_new(command, %{parse_tree: Parser.rule_to_json!(rule),
                          score: rule.score})
  end
  def insert_new(%Command{}=command, params) do
    command
    |> Ecto.Model.build(:rules, params)
    |> changeset(params)
    |> Repo.insert
  end

  def changeset(model, params) do
    model
    |> Changeset.cast(params, @required_fields, @optional_fields)
    |> unique_constraint(:no_dupes, name: :rules_command_id_parse_tree_index)
  end

  def parse_name(name) do
    case String.split(name, ":", parts: 2) do
      [namespace, permission] ->
        {:ok, {namespace, permission}}
      _ ->
        {:error, {:invalid_permission, name}}
    end
  end
end

defimpl Permittable, for: Cog.Models.Rule do
  def grant_to(rule, permission),
    do: Cog.Models.JoinTable.associate(rule, permission)

  def revoke_from(_, _),
    do: raise "unimplemented"
end

defimpl Poison.Encoder, for: Cog.Models.Rule do
  def encode(rule, options) do
    ast = Piper.Permissions.Parser.json_to_rule!(rule.parse_tree)

    rule
    |> Map.from_struct
    |> Map.take([:id])
    |> Map.put_new(:command, ast.command)
    |> Map.put_new(:rule, to_string(ast))
    |> Poison.Encoder.Map.encode(options)
  end
end
