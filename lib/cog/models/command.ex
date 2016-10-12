defmodule Cog.Models.Command do
  use Cog.Model

  alias Cog.Queries
  alias Cog.Models.Bundle
  alias Cog.Models.CommandVersion
  alias Cog.Models.Rule
  require Logger

  schema "commands" do
    field :name, :string
    belongs_to :bundle, Bundle

    has_many :versions, CommandVersion
    has_many :rules, Rule

    timestamps
  end

  @required_fields ~w(name bundle_id)
  @optional_fields ~w()

  summary_fields [:id, :name]
  detail_fields [:id, :name]

  @doc """
  Create a new changeset for a command, associating it with its parent
  bundle (which must already exist in the database).

  Does _not_ insert anything into the database.
  """
  def build_new(%Bundle{id: _}=bundle, params) do
    bundle
    |> Ecto.build_assoc(:commands)
    |> changeset(params)
  end

  @doc """
  Splits a fully qualified command name into bundle and command
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

  def parse_name(name) do
    case parse_qualified_name(name) do
      {:ok, command} ->
        {:ok, command}
      {:error, _} ->
        parse_ambiguous_name(name)
    end
  end

  def parse_qualified_name(name) do
    case String.split(name, ":", parts: 2) do
      [bundle, command] ->
        result = Queries.Command.named(bundle, command)
        |> Repo.one

        case result do
          nil ->
            {:error, {:command_not_found, name}}
          command ->
            {:ok, command}
        end
      _ ->
        {:error, {:command_invalid, name}}
    end
  end

  def parse_ambiguous_name(name) do
    result = Queries.Command.by_name(name)
    |> Repo.all

    case result do
      [command] ->
        {:ok, command}
      [] ->
        {:error, {:command_not_found, name}}
      _ ->
        {:error, {:command_ambiguous, name}}
    end
  end

  @doc """
  *DEPRECATED* This couples changeset creation with database
   insertion, which is not what you always want.

  Use `build_new/2` instead.
  """
  # TODO: only used in tests right now
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
  end
end

# TODO: Is this used anywhere?
defimpl Poison.Encoder, for: Cog.Models.Command do
  def encode(%Cog.Models.Command{} = struct, options) do
    map = struct
    |> Map.from_struct
    |> Map.take([:name, :version, :documentation, :bundle])

    Poison.Encoder.Map.encode(map, options)
  end
end
