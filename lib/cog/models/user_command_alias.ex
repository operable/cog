defmodule Cog.Models.UserCommandAlias do
  use Cog.Model
  use Cog.Models

  require Logger

  schema "user_command_aliases" do
    field :name, :string
    field :pipeline, :string
    field :visibility, :string, virtual: true, default: "user"

    belongs_to :user, User

    timestamps
  end

  @required_fields ~w(name pipeline user_id)
  @optional_fields ~w()

  summary_fields [:name, :pipeline, :visibility]
  detail_fields [:name, :pipeline, :visibility]

  def changeset(model, params) do
    model
    |> cast(params, @required_fields, @optional_fields)
    |> unique_constraint(:name, name: :user_command_aliases_name_user_id_index, message: "The alias name is already in use.")
  end
end

