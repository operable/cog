defmodule Cog.Models.PermissionBundleVersion do
  use Cog.Model
  alias Cog.Models.{Permission, BundleVersion}

  @primary_key false

  schema "permission_bundle_version" do
    belongs_to :permission, Permission, primary_key: true
    belongs_to :bundle_version, BundleVersion, primary_key: true
  end

  # Insertions are handled via JoinTable, so nothing else is needed
  # for this model
end
