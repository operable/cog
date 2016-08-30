defmodule Cog.Models.BundleVersion do
  use Cog.Model
  use Cog.Models

  schema "bundle_versions" do
    field :version, VersionTriple
    field :config_file, :map
    field :description, :string
    field :long_description, :string
    field :author, :string
    field :homepage, :string
    field :status, :string, virtual: true

    belongs_to :bundle, Bundle

    has_many :commands, CommandVersion # TODO: or `:command_versions`?
    has_many :templates, Template

    has_many :permission_registration, Cog.Models.PermissionBundleVersion
    has_many :permissions, through: [:permission_registration, :permission]

    has_many :rule_registration, Cog.Models.RuleBundleVersion
    has_many :rules, through: [:rule_registration, :rule]

    has_one :enabled_version_registration, Cog.Models.EnabledBundleVersionRegistration, foreign_key: :bundle_version_id

    timestamps
  end

  @required_fields ~w(version config_file)
  @optional_fields ~w(description long_description author homepage)

  summary_fields [:id, :inserted_at]
  detail_fields [:id, :inserted_at]

  def changeset(model, params \\ :empty) do
    model
    |> cast(params, @required_fields, @optional_fields)
    |> unique_constraint(:version,
                         name: :bundle_versions_bundle_id_version_index)
  end

end

defimpl Poison.Encoder, for: Cog.Models.BundleVersion do
  def encode(%Cog.Models.BundleVersion{} = bundle_version, options) do
    bundle = bundle_version.bundle
    bundle_version = Map.from_struct(bundle_version)

    map = %{}
    |> Map.merge(Map.take(bundle, [:name]))
    |> Map.merge(Map.take(bundle_version, [:version, :status]))

    map = Map.update!(map, :version, &to_string/1)

    Poison.Encoder.Map.encode(map, options)
  end
end
