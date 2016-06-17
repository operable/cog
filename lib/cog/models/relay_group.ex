defmodule Cog.Models.RelayGroup do
  use Cog.Model

  alias Cog.Models.RelayGroupMembership
  alias Cog.Models.RelayGroupAssignment
  alias Cog.Repo

  schema "relay_groups" do
    field :name, :string
    field :desc, :string

    has_many :relay_membership, RelayGroupMembership, foreign_key: :group_id
    has_many :relays, through: [:relay_membership, :relay]

    has_many :bundle_assignment, RelayGroupAssignment, foreign_key: :group_id
    has_many :bundles, through: [:bundle_assignment, :bundle]

    timestamps
  end

  @required_fields ~w(name)
  @optional_fields ~w(desc)

  def changeset(model, params \\ :empty) do
    model
    |> Repo.preload([:bundles, :relays])
    |> cast(params, @required_fields, @optional_fields)
    |> unique_constraint(:name)
  end

end

defimpl Groupable, for: Cog.Models.RelayGroups do

  def add_to(member, relay_group) do
    Cog.Models.JoinTable.associate(member, relay_group)
  end

  def remove_from(member, relay_group) do
    Cog.Models.JoinTable.dissociate(member, relay_group)
  end

end
