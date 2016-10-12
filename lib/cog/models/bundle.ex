defmodule Cog.Models.Bundle do
  use Cog.Model

  alias Cog.Models.BundleVersion
  alias Cog.Models.Command
  alias Cog.Models.EnabledBundleVersionRegistration
  alias Cog.Models.Permission
  alias Cog.Models.RelayGroupAssignment

  schema "bundles" do
    field :name, :string

    has_many :versions, BundleVersion
    has_many :commands, Command
    has_many :permissions, Permission

    has_many :group_assignments, RelayGroupAssignment
    has_many :relay_groups, through: [:group_assignments, :group]

    has_one :enabled_version_registration, EnabledBundleVersionRegistration
    has_one :enabled_version, through: [:enabled_version_registration, :bundle_version]

    timestamps
  end

  @required_fields ~w(name)
  @optional_fields ~w()

  summary_fields [:id, :name, :inserted_at]
  detail_fields [:id, :name, :inserted_at]

  def changeset(model, params \\ :empty) do
    model
    |> Repo.preload(:relay_groups)
    |> cast(params, @required_fields, @optional_fields)
    |> validate_format(:name, ~r/\A[A-Za-z0-9\_\-\.]+\z/)
    |> unique_constraint(:name, name: :bundles_name_index, message: "The bundle name is already in use.")
  end

end

defimpl Groupable, for: Cog.Models.Bundle do

  def add_to(bundle, relay_group) do
    if bundle.name in [Cog.Util.Misc.embedded_bundle, Cog.Util.Misc.site_namespace] do
      raise Cog.ProtectedBundleError, bundle.name
    else
      Cog.Models.JoinTable.associate(bundle, relay_group)
    end
  end
  def remove_from(bundle, relay_group),
    do: Cog.Models.JoinTable.dissociate(bundle, relay_group)

end

defimpl Poison.Encoder, for: Cog.Models.Bundle do
  def encode(struct, options) do
    map = struct
    |> Map.from_struct
    |> Map.take([:name])

    Poison.Encoder.Map.encode(map, options)
  end
end
