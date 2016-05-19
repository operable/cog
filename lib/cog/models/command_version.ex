defmodule Cog.Models.CommandVersion do
  use Cog.Model
  use Cog.Models

  require Logger

  schema "command_versions_v2" do
    field :documentation, :string

    belongs_to :command, Command
    belongs_to :bundle_version, BundleVersion

    has_many :options, CommandOption

    timestamps
  end

  @required_fields ~w()
  @optional_fields ~w(documentation)

  summary_fields [:documentation]
  detail_fields [:documentation]

  @doc """
  Create a new changeset for a command, associating it with its parent
  bundle (which must already exist in the database).

  Does _not_ insert anything into the database.
  """
  def build_new(%BundleVersion{id: _}=bundle_version, params) do
    bundle_version
    |> Ecto.Model.build(:command_versions)
    |> changeset(params)
  end

  def changeset(model, params) do
    model
    |> cast(params, @required_fields, @optional_fields)
    |> foreign_key_constraint(:bundle_id)
    |> foreign_key_constraint(:command_id)
  end

  def full_name(%Cog.Models.CommandVersion{}=cv),
    do: "#{cv.command.bundle.name}:#{cv.command.name}"
end
