defmodule Cog.Repository.Triggers do
  @moduledoc """
  Behavioral API for interacting with triggers. Prefer these
  functions over direct manipulation with `Cog.Repo`.
  """

  alias Cog.Repo
  alias Cog.Models.Trigger

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

  def by_name(name),
    do: Repo.all(with_name(name))

  def delete(%Trigger{}=trigger) do
    try do
      Repo.delete(trigger)
    rescue
      Ecto.StaleModelError ->
        {:error, :not_found}
    end
  end

  def update(%Trigger{}=trigger, attrs) do
    trigger
    |> Trigger.changeset(attrs)
    |> Repo.update
  end

  ########################################################################

  defp with_name(queryable \\ Trigger, name) do
    from t in queryable,
    where: t.name == ^name
  end

end
