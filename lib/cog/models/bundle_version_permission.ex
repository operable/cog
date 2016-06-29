defmodule Cog.Models.PermissionBundleVersion do
  use Cog.Model

  @primary_key false
  schema "permission_bundle_version" do
    belongs_to :permission, Cog.Models.Permission, references: :id
    belongs_to :bundle_version, Cog.Models.BundleVersion, references: :id
  end

  # Insertions are handled via JoinTable, so nothing else is needed
  # for this model
end
