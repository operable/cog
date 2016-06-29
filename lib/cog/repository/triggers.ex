defmodule Cog.Repository.Triggers do
  @moduledoc """
  Behavioral API for interacting with triggers. Prefer these
  functions over direct manipulation with `Cog.Repo`.
  """

  alias Cog.Repo
  alias Cog.Models.Trigger

  require Ecto.Query
  import Ecto.Query, only: [from: 2]

  @doc """
  Retrieve the definition of the given trigger. The given id must
  be a valid UUID.
  """
  @spec trigger_definition(String.t) :: {:ok, %Trigger{}} | {:error, :not_found | :bad_id}
  def trigger_definition(id) do
    if Cog.UUID.is_uuid?(id) do
      case Repo.get(Trigger, id) do
        %Trigger{} = trigger ->
          {:ok, trigger}
        nil ->
          {:error, :not_found}
      end
    else
      {:error, :bad_id}
    end
  end

  @doc """
  Create a new trigger given a map of attributes.
  """
  @spec new(Map.t) :: {:ok, %Trigger{}} | {:error, Ecto.Changeset.t}
  def new(attrs) do
    %Trigger{}
    |> Trigger.changeset(attrs)
    |> Repo.insert
  end

  @doc """
  Retrieve all triggers. Order is undefined.
  """
  @spec all :: [%Trigger{}]
  def all,
    do: Repo.all(Trigger)

  def by_name(name) do
    case Repo.get_by(Trigger, name: name) do
      %Trigger{} = trigger ->
        {:ok, trigger}
      nil ->
        {:error, :not_found}
    end
  end

  def delete(%Trigger{}=trigger) do
    try do
      Repo.delete(trigger)
    rescue
      Ecto.StaleEntryError ->
        {:error, :not_found}
    end
  end
  def delete(names) when is_list(names) do
    # TODO: use returning: true with ecto 2.0 and Repo.delete_all; the
    # return value here anticipates this
    triggers = Repo.all(from t in Trigger, where: t.name in ^names)
    Enum.each(triggers, &Repo.delete/1)
    {length(triggers), triggers}
  end

  def update(%Trigger{}=trigger, attrs) do
    trigger
    |> Trigger.changeset(attrs)
    |> Repo.update
  end

end
