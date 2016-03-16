defmodule Cog.Models.Command do
  use Cog.Model
  use Cog.Models

  require Logger

  schema "commands" do
    field :name, :string
    field :documentation, :string
    field :enforcing, :boolean, default: true
    field :calling_convention, :string, default: "bound"
    field :execution, :string, default: "multiple"

    belongs_to :bundle, Bundle

    has_many :rules, Rule
    has_many :options, CommandOption
  end

  @required_fields ~w(name bundle_id)
  @optional_fields ~w(documentation enforcing calling_convention execution)

  summary_fields [:id, :name]
  detail_fields [:id, :name, :documentation]

  @doc """
  Create a new changeset for a command, associating it with its parent
  bundle (which must already exist in the database).

  Does _not_ insert anything into the database.
  """
  def build_new(%Bundle{id: _}=bundle, params) do
    bundle
    |> Ecto.Model.build(:commands)
    |> changeset(params)
  end

  @doc """
  Splits a fully qualified command name into namespace and command
  name.
  """
  def split_name(name) do
    case String.split(name, "::", parts: 2) do
      [bundle, command] ->
        {bundle, command}
      [_] ->
        case String.split(name, ":", parts: 2) do
          [bundle, command] ->
            {bundle, command}
          [_] ->
            {name, name}
        end
    end
  end

  @doc """
  Get the fully qualified name; depends on bundle being preloaded.
  """
  def full_name(%__MODULE__{}=command) do
    "#{command.bundle.name}:#{command.name}"
  end


  @doc """
  *DEPRECATED* This couples changeset creation with database
   insertion, which is not what you always want.

  Use `build_new/2` instead.
  """
  def insert_new(params) do
    Logger.warn "#{inspect __MODULE__}.insert_new/1 is deprecated! Favor `build_new/1` instead"
    %__MODULE__{}
    |> changeset(params)
    |> Repo.insert
  end

  def changeset(model, params) do
    model
    |> cast(params, @required_fields, @optional_fields)
    |> validate_format(:name, ~r/\A[A-Za-z0-9\_\-\.]+\z/)
    |> foreign_key_constraint(:bundle_id)
    |> unique_constraint(:bundle, name: "bundled_command_name")
  end

end

defimpl Poison.Encoder, for: Cog.Models.Command do
  def encode(%Cog.Models.Command{} = struct, options) do
    map = struct
    |> Map.from_struct
    |> Map.take([:name, :version])

    Poison.Encoder.Map.encode(map, options)
  end
end
