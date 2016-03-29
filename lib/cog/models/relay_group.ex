defmodule Cog.Models.RelayGroup do
  use Cog.Model

  alias Cog.Models.RelayGroupMembership

  schema "relay_groups" do
    field :name, :string
    has_many :relay_membership, RelayGroupMembership, foreign_key: :group_id
    has_many :relays, through: [:relay_membership, :relay]

    timestamps
  end

  @required_fields ~w(name)
  @optional_fields ~w()

  def changeset(model, params \\ :empty) do
    model
    |> cast(params, @required_fields, @optional_fields)
    |> unique_constraint(:name)
  end

end
