defmodule Cog.Repository.RelayGroups do
  @moduledoc """
  Behavioral API for interacting with relay groups. Prefer these
  functions over direct manipulation with 'Cog.Repo'.
  """

  alias Cog.Repo
  alias Cog.Models.RelayGroup

  @doc """
  Creates a new relay group given a map of attributes
  """
  @spec new(Map.t) :: {:ok, %RelayGroup{}} | {:error, Ecto.Changeset.t}
  def new(attrs) do
    %RelayGroup{}
    |> RelayGroup.changeset(attrs)
    |> Repo.insert
  end

  @doc """
  Retrieves all relay groups.
  """
  @spec all :: [%RelayGroup{}]
  def all,
    do: Repo.all(RelayGroup) |> Repo.preload([:bundles, :relays])

  @doc """
  Retrieves a single relay group based on the id. The given id must a
  valid UUID.
  """
  @spec by_id(String.t) :: {:ok, %RelayGroup{}} | {:error, Ecto.Changeset.t} | {:error, Atom.t}
  def by_id(id) do
    with :ok <- valid_uuid(id) do
      case Repo.get(RelayGroup, id) |> Repo.preload([:bundles, :relays]) do
        %RelayGroup{} = relay_group ->
          {:ok, relay_group}
        nil ->
          {:error, :not_found}
      end
    end
  end

  @doc """
  Retrieves a single relay group based on it's name.
  """
  @spec by_name(String.t) :: {:ok, %RelayGroup{}} | {:error, :not_found}
  def by_name(name) do
    case Repo.get_by(RelayGroup, name: name) do
      %RelayGroup{} = relay_group ->
        {:ok, relay_group}
      nil ->
        {:error, :not_found}
    end
  end

  @doc """
  Deletes a relay group.
  """
  @spec delete(String.t | %RelayGroup{}) :: {:ok, %RelayGroup{}} | {:error, Ecto.Changeset.t} | {:error, Atom.t}
  def delete(%RelayGroup{}=relay_group) do
    try do
      Repo.delete(relay_group)
    rescue
      Ecto.StaleModelError ->
        {:error, :not_found}
    end
  end
  def delete(id) do
    case by_id(id) do
      {:ok, relay_group} ->
        delete(relay_group)
      error ->
        error
    end
  end

  @doc """
  Updates a relay group.
  """
  @spec update(String.t | %RelayGroup{}, Map.t) :: {:ok, %RelayGroup{}} | {:error, Ecto.Changeset.t}
  def update(%RelayGroup{}=relay_group, attrs) do
    changeset = RelayGroup.changeset(relay_group, attrs)
    case Repo.update(changeset) do
      {:ok, relay_group} ->
        {:ok, relay_group}
      {:error, changeset} ->
        {:error, changeset}
    end
  end
  def update(id, attrs) do
    case by_id(id) do
      {:ok, relay_group} ->
        update(relay_group, attrs)
      error ->
        error
    end
  end

  defp valid_uuid(id) do
    if Cog.UUID.is_uuid?(id) do
      :ok
    else
      {:error, :bad_id}
    end
  end
end
