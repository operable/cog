defmodule Cog.Models.Bundle do
  use Cog.Model
  use Cog.Models

  schema "bundles" do
    field :name, :string
    field :config_file, :map
    field :manifest_file, :map

    has_many :commands, Command
    has_many :templates, Template
    has_one :namespace, Namespace

    timestamps
  end

  @required_fields ~w(name config_file manifest_file)

  summary_fields [:id, :name, :namespace, :inserted_at]
  detail_fields [:id, :name, :namespace, :commands, :inserted_at]

  def changeset(model, params \\ :empty) do
    model
    |> cast(params, @required_fields)
    |> validate_format(:name, ~r/\A[A-Za-z0-9\_\-\.]+\z/)
    |> unique_constraint(:name)
  end

  def embedded?(%__MODULE__{name: name}),
    do: name == Cog.embedded_bundle
  def embedded?(_),
    do: false

  def bundle_path(%__MODULE__{name: name}) do
    Path.join(bundle_root!, name)
  end

  def bundle_ebin_path(bundle) do
    Path.join(bundle_path(bundle), "ebin")
  end

  def bundle_root! do
    Application.get_env(:cog, Cog.Bundle.BundleSup)
    |> Keyword.fetch!(:bundle_root)
  end

  def bundle_root do
    Application.get_env(:cog, Cog.Bundle.BundleSup)
    |> Keyword.get(:bundle_root, nil)
  end
end
