defmodule Cog.Models.RulePermission do
  use Cog.Model

  @primary_key false
  schema "rule_permissions" do
    belongs_to :rule, Cog.Models.Rule, references: :id
    belongs_to :permission, Cog.Models.Permission, references: :id
  end

  @required_fields ~w(rule_id permission_id)

  def changeset(model, params) do
    model
    |> cast(params, @required_fields)
    |> unique_constraint(:permission_grant , name: "rule_permissions_rule_id_permission_id_index")
  end

end
