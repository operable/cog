defmodule Cog.Models.UserCommandAlias do
  use Cog.Model
  use Cog.Models

  require Logger

  schema "user_command_aliases" do
    field :name, :string
    field :pipeline, :string

    belongs_to :user, User
  end

  @required_fields ~w(name pipeline user_id)
  @optional_fields ~w()

  def changeset(model, params) do
    model
    |> cast(params, @required_fields, @optional_fields)
    |> unique_constraint(:name, name: :user_command_aliases_name_user_id_index)
  end
end

