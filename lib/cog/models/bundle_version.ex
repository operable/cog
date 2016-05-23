defmodule Cog.Models.BundleVersion do
  use Cog.Model
  use Cog.Models

  schema "bundle_versions_v2" do
    field :version, VersionTriple
    field :config_file, :map

    belongs_to :bundle, Bundle

    has_many :commands, CommandVersion # TODO: or `:command_versions`?
    has_many :templates, Template

    has_many :permission_registration, Cog.Models.PermissionBundleVersion
    has_many :permissions, through: [:permission_registration, :permission]

    has_one :enabled_version_registration, Cog.Models.EnabledBundleVersionRegistration, foreign_key: :bundle_version_id

    timestamps
  end

  @required_fields ~w(version config_file)

  summary_fields [:id, :inserted_at]
  detail_fields [:id, :inserted_at]

  def changeset(model, params \\ :empty) do
    model |> cast(params, @required_fields, [])
  end

end
