defmodule Cog.Models.CommandVersion do
  use Cog.Model
  use Cog.Models

  require Logger

  schema "command_versions" do
    field :description, :string
    field :long_description, :string
    field :examples, :string
    field :notes, :string
    field :arguments, :string
    field :subcommands, :map
    field :documentation, :string
    field :status, :string, virtual: true

    belongs_to :command, Command
    belongs_to :bundle_version, BundleVersion

    has_many :options, CommandOption

    timestamps
  end

  @required_fields ~w(command_id bundle_version_id)
  @optional_fields ~w(description documentation long_description examples notes arguments subcommands)

  summary_fields [:documentation]
  detail_fields [:documentation]

  @doc """
  Create a new changeset for a command, associating it with its parent
  bundle (which must already exist in the database).

  Does _not_ insert anything into the database.
  """
  def build_new(%BundleVersion{id: _}=bundle_version, params) do
    bundle_version
    |> Ecto.build_assoc(:command_versions)
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

defimpl Poison.Encoder, for: Cog.Models.CommandVersion do
  def encode(%Cog.Models.CommandVersion{} = command_version, options) do
    command = Map.from_struct(command_version.command)
    command_version = Map.from_struct(command_version)

    map = %{}
    |> Map.merge(Map.take(command, [:name, :bundle]))
    |> Map.merge(Map.take(command_version, [:version, :documentation]))

    Poison.Encoder.Map.encode(map, options)
  end
end
