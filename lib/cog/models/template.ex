defmodule Cog.Models.Template do
  use Cog.Model
  use Cog.Models

  schema "templates" do
    field :adapter, :string
    field :name, :string
    field :source, :string

    belongs_to :bundle, Bundle

    timestamps
  end

  @required_fields ~w(adapter name source)
  @optional_fields ~w()

  def changeset(model, params \\ :empty) do
    model
    |> cast(params, @required_fields, @optional_fields)
    |> unique_constraint(:name, name: :templates_bundle_id_name_index)
  end
end
