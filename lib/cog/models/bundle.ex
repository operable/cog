defmodule Cog.Models.Bundle do
  use Cog.Model
  use Cog.Models

  schema "bundles" do
    field :name, :string
    field :config_file, :map
    field :manifest_file, :map
    field :enabled, :boolean, default: false

    has_many :commands, Command
    has_many :templates, Template
    has_one :namespace, Namespace

    timestamps
  end

  @required_fields ~w(name config_file manifest_file)
  @optional_fields ~w(enabled)

  summary_fields [:id, :name, :namespace, :inserted_at, :enabled]
  detail_fields [:id, :name, :namespace, :commands, :inserted_at, :enabled]

  def changeset(model, params \\ :empty) do
    model
    |> cast(params, @required_fields, @optional_fields)
    |> validate_format(:name, ~r/\A[A-Za-z0-9\_\-\.]+\z/)
    |> unique_constraint(:name, name: :bundles_name_index)
    |> enable_if_embedded
  end

  def embedded?(%__MODULE__{name: name}),
    do: name == Cog.embedded_bundle
  def embedded?(_),
    do: false

  # When the embedded bundle is installed, it should always be
  # enabled. Though we prevent disabling it elsewhere, this code also
  # happens to block that, as well.
  #
  # Nothing is changed if it is not the embedded bundle.
  defp enable_if_embedded(changeset) do
    embedded = Cog.embedded_bundle
    case fetch_field(changeset, :name) do
      {_, ^embedded} ->
        put_change(changeset, :enabled, true)
      _ ->
        changeset
    end
  end

end
