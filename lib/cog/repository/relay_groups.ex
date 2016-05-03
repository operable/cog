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
  Updates a relay group.
  """
  @spec update(String.t, Map.t) :: {:ok, %RelayGroup{}} | {:error, Ecto.Changeset.t}
  def update(id, attrs) do
    with {:ok, relay_group} <- by_id(id) do
      changeset = RelayGroup.changeset(relay_group, attrs)
      case Repo.update(changeset) do
        {:ok, relay_group} ->
          {:ok, relay_group}
        {:error, changeset} ->
          {:error, changeset}
      end
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
