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


  def changeset(model),
    do: changeset(model, %{})

  def changeset(model, :delete) do
    %{Ecto.Changeset.change(model) | action: :delete}
    |> relay_group_assignment_constraint
    |> relay_group_membership_constraint
  end

  def changeset(model, params) do
    model
    |> Repo.preload([:bundles, :relays])
    |> cast(params, @required_fields, @optional_fields)
    |> relay_group_assignment_constraint
    |> relay_group_membership_constraint
    |> unique_constraint(:name)
  end

  defp relay_group_assignment_constraint(changeset) do
    foreign_key_constraint(changeset,
                           :id,
                           name: :relay_group_assignments_group_id_fkey,
                           message: "cannot delete relay group that has bundles assigned")
  end

  defp relay_group_membership_constraint(changeset) do
    foreign_key_constraint(changeset,
                           :id,
                           name: :relay_group_memberships_group_id_fkey,
                           message: "cannot delete relay group that has relay members")
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
