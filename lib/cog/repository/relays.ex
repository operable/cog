defmodule Cog.Repository.Relays do
  @moduledoc """
  Behavioral API for interacting with relays. Prefer these
  functions over direct manipulation with `Cog.Repo`.
  """

  alias Cog.Repo
  alias Cog.Models.Relay
  alias Cog.Relay.Relays
  import Ecto.Query, only: [from: 1, from: 2]

  @doc """
  Creates a new relay given a map of attributes
  """
  @spec new(Map.t) :: {:ok, %Relay{}} | {:error, Ecto.Changeset.t}
  def new(attrs) do
    %Relay{}
    |> Relay.changeset(attrs)
    |> Repo.insert
  end

  @doc """
  Retrieves all relays.
  """
  @spec all :: [%Relay{}]
  def all,
    do: Repo.all(Relay) |> preload

  @doc """
  Retrieves a relay based on the id. The given id must be a
  valid UUID.
  """
  @spec by_id(String.t) :: {:ok, %Relay{}} | {:error, Ecto.Changeset.t} | {:error, Atom.t}
  def by_id(id) do
    with :ok <- valid_uuid(id) do
      case Repo.get(Relay, id) do
        %Relay{} = relay ->
          {:ok, preload(relay)}
        nil ->
          {:error, :not_found}
      end
    end
  end

  defp preload(relay_or_relays),
    do: Repo.preload(relay_or_relays, [groups: :bundles])

  @doc """
  Retrieves a single relay based on it's name or a list of relays based on
  a list of names.
  """
  @spec by_name(String.t | List.t) :: {:ok, %Relay{}} | {:error, :not_found}
  def by_name(names) when is_list(names) do
    case Repo.all(from r in Relay, where: r.name in ^names) do
      [] ->
        {:error, :not_found}
      relays ->
        {:ok, preload(relays)}
    end
  end
  def by_name(name) do
    case Repo.get_by(Relay, name: name) do
      %Relay{} = relay ->
        {:ok, preload(relay)}
      nil ->
        {:error, :not_found}
    end
  end

  @doc """
  Removes a relay from the db and from the internal tracker
  """
  @spec delete(String.t) :: {:ok, %Relay{}} | {:error, Ecto.Changeset.t} | {:error, Atom.t}
  def delete(id) do
    try do
      with {:ok, relay} <- by_id(id),
           {:ok, deleted_relay} <- Repo.delete(relay),
           :ok <- Relays.drop_relay(relay),
             do: {:ok, deleted_relay}
    rescue
      Ecto.StaleModelError ->
        {:error, :not_found}
    end
  end

  @doc """
  Updates a relay. Toggles the relay status if the update
  changes the status.
  """
  @spec update(String.t, Map.t) :: {:ok, %Relay{}} | {:error, Ecto.Changeset.t}
  def update(id, attrs) do
    with {:ok, relay} <- by_id(id) do
      changeset = Relay.changeset(relay, attrs)
      case Repo.update(changeset) do
        {:ok, relay} ->
          # If the enabled flag has changed we need to enable/disable the relay
          if Map.has_key?(changeset.changes, :enabled) do
            update_relay_status(relay)
          end
          {:ok, relay}
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

  defp update_relay_status(%Relay{enabled: true}=relay),
    do: Relays.enable_relay(relay)
  defp update_relay_status(%Relay{enabled: false}=relay),
    do: Relays.disable_relay(relay)

end
