defmodule Cog.Models.CommandOptionType do
  use Cog.Model

  schema "command_option_types" do
    field :name, :string
  end

  @required_fields ~w(name)

  summary_fields [:name]
  detail_fields [:name]

  def insert_new!(params) do
    %__MODULE__{}
    |> changeset(params)
    |> Repo.insert!
  end

  def changeset(model, params) do
    model
    |> cast(params, @required_fields)
    |> unique_constraint(:name, name: :command_option_types_name_index)
  end

end

defmodule Cog.Models.CommandOption do
  require Logger
  use Cog.Model
  alias Ecto.Changeset
  alias Cog.Models.Command
  alias Cog.Models.CommandOptionType

  schema "command_options" do
    field :name, :string
    field :required, :boolean
    field :type, :string, virtual: true
    field :short_flag, :string
    field :long_flag, :string
    field :desc, :string
    belongs_to :command, Cog.Models.Command

    belongs_to :option_type, Cog.Models.CommandOptionType
  end

  @required_fields ~w(name required command_id)
  @optional_fields ~w(desc type option_type_id short_flag long_flag)

  summary_fields [:id, :name, :required]
  detail_fields [:id, :name, :required, :short_flag, :long_flag,
                 :option_type]

  @doc """
  Create a new changeset for a command option, associating it with its
  parent command (which must already exist in the database).

  Does _not_ insert anything into the database.
  """
  def build_new(%Command{}=command, params) do
    command
    |> Ecto.Model.build(:options)
    |> changeset(params)
  end

  @doc """
  *DEPRECATED* This couples changeset creation with database
   insertion, which is not what you always want.

  Use `build_new/2` instead.
  """
  def insert_new(%Command{}=command, params) do
    Logger.warn "#{inspect __MODULE__}.insert_new/2 is deprecated! Favor `build_new/2` instead"
    %__MODULE__{}
    |> changeset(Map.put(params, :command_id, command.id))
    |> Repo.insert
  end

  def changeset(model, params) do
    model
    |> cast(params, @required_fields, @optional_fields)
    |> ensure_type_name_on_create
    |> validate_change(:type, fn
      (:type, tn) when is_binary(tn) -> [];
      (:type, _) -> [type: "must be a string"]
    end)
    |> resolve_type
    |> generate_flag_names
    |> clean_flag(:short_flag)
    |> clean_flag(:long_flag)
    |> unique_constraint(:name, name: :command_options_command_id_name_index)
  end

  defp clean_flag(changeset, flag_type) do
    case fetch_change(changeset, flag_type) do
      :error ->
        changeset
      {:ok, flag} ->
        case Regex.replace(~r/(^--|^-)/, flag, "", global: false) do
          ^flag ->
            changeset
          flag ->
            put_change(changeset, flag_type, flag)
        end
    end
  end

  defp generate_flag_names(changeset) do
    case is_create?(changeset) do
      false ->
        changeset
      true ->
        case {fetch_change(changeset, :short_flag), fetch_change(changeset, :long_flag)} do
          # No flag names set so we'll generate a long one based on the option name
          {:error, :error} ->
            {:ok, name} = fetch_change(changeset, :name)
            changeset
            |> put_change(:long_flag, name)
          _ ->
            changeset
        end
    end
  end

  defp ensure_type_name_on_create(changeset) do
    case is_create?(changeset) do
      true ->
        case fetch_change(changeset, :type) do
          :error ->
            Changeset.add_error(changeset, :type, "must specify option type")
          _ ->
            changeset
        end
      false ->
        changeset
    end
  end

  defp resolve_type(changeset) do
    case fetch_change(changeset, :type) do
      :error ->
        changeset
      {:ok, name} ->
        case Repo.get_by(CommandOptionType, name: name) do
          nil ->
            Changeset.add_error(changeset, :type, "unknown option type name '#{name}'")
          option_type ->
            changeset
            |> put_change(:option_type_id, option_type.id)
            |> delete_change(:type)
        end
    end
  end

  defp is_create?(changeset) do
    fetch_field(changeset, :id) == {:model, nil}
  end

end
