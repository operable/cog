defmodule Cog.Models.RuleBundleVersion do
  use Cog.Model
  alias Cog.Models.{Rule, BundleVersion}

  @primary_key false

  schema "rule_bundle_version" do
    belongs_to :rule, Rule, primary_key: true
    belongs_to :bundle_version, BundleVersion, primary_key: true
  end

  # Insertions are handled via JoinTable, so nothing else is needed
  # for this model
end
