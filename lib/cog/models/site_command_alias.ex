defmodule Cog.Models.SiteCommandAlias do
  use Cog.Model
  use Cog.Models

  require Logger

  schema "site_command_aliases" do
    field :name, :string
    field :pipeline, :string
  end

  @required_fields ~w(name pipeline)
  @optional_fields ~w()

  def changeset(model, params) do
    model
    |> cast(params, @required_fields, @optional_fields)
    |> unique_constraint(:name, name: :site_command_aliases_name_index)
  end
end
