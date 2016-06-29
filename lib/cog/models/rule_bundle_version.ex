defmodule Cog.Models.RuleBundleVersion do
  use Cog.Model

  @primary_key false
  schema "rule_bundle_version" do
    belongs_to :rule, Cog.Models.Rule, references: :id
    belongs_to :bundle_version, Cog.Models.BundleVersion, references: :id
  end

  # Insertions are handled via JoinTable, so nothing else is needed
  # for this model
end
