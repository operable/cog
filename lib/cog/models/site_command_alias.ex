defmodule Cog.Models.SiteCommandAlias do
  use Cog.Model
  use Cog.Models

  require Logger

  schema "site_command_aliases" do
    field :name, :string
    field :pipeline, :string
    field :visibility, :string, virtual: true, default: "site"

    timestamps
  end

  @required_fields ~w(name pipeline)
  @optional_fields ~w()

  summary_fields [:name, :pipeline, :visibility]
  detail_fields [:name, :pipeline, :visibility]

  def changeset(model, params) do
    model
    |> cast(params, @required_fields, @optional_fields)
    |> unique_constraint(:name, name: :site_command_aliases_name_index, message: "The alias name is already in use.")
  end
end
