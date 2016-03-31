defmodule Cog.Models.RelayGroup do
  use Cog.Model

  alias Cog.Models.RelayGroupMembership
  alias Cog.Models.RelayGroupAssignment
  alias Cog.Repo

  schema "relay_groups" do
    field :name, :string

    has_many :relay_membership, RelayGroupMembership, foreign_key: :group_id
    has_many :relays, through: [:relay_membership, :relay]

    has_many :bundle_assignment, RelayGroupAssignment, foreign_key: :group_id
    has_many :bundles, through: [:bundle_assignment, :bundle]

    timestamps
  end

  @required_fields ~w(name)
  @optional_fields ~w()

  def changeset(model, params \\ :empty) do
    model
    |> Repo.preload([:bundles, :relays])
    |> cast(params, @required_fields, @optional_fields)
    |> unique_constraint(:name)
  end

  def add!(:bundle, group_id, bundle_id),
  do: add_bundles!(group_id, bundle_id)

  def add!(:relay, group_id, relay_ids),
  do: add_relays!(group_id, relay_ids)

  def remove(:bundle, group_id, bundle_ids),
  do: remove_bundles(group_id, bundle_ids)

  def remove(:relay, group_id, relay_ids),
  do: remove_relays(group_id, relay_ids)

  def add_relays!(group_id, relay_ids) when is_list(relay_ids) do
    Enum.reduce(relay_ids, [], fn(id, acc) ->
      rgm =
        %RelayGroupMembership{}
        |> RelayGroupMembership.changeset(%{relay_id: id, group_id: group_id})
        |> Repo.insert!
      [rgm|acc]
    end)
  end

  def remove_relays(group_id, relay_ids) when is_list(relay_ids) do
    {count, _} = Repo.delete_all(from rgm in RelayGroupMembership,
                                 where: rgm.group_id == ^group_id and rgm.relay_id in ^relay_ids)
    count
  end

  def add_bundles!(group_id, bundle_ids) when is_list(bundle_ids) do
    Enum.reduce(bundle_ids, [], fn(id, acc) ->
      rga =
        %RelayGroupAssignment{}
        |> RelayGroupAssignment.changeset(%{bundle_id: id, group_id: group_id})
        |> Repo.insert!
      [rga|acc]
    end)
  end

  def remove_bundles(group_id, bundle_ids) when is_list(bundle_ids) do
    {count, _} = Repo.delete_all(from rgm in RelayGroupAssignment,
                                 where: rgm.group_id == ^group_id and rgm.bundle_id in ^bundle_ids)
    count
  end

end
