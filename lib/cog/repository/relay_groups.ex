defmodule Cog.Repository.RelayGroups.BadIdError do
  defexception [:message]

  def exception(value) do
    msg = "'#{value}' is not a valid uuid"
    %__MODULE__{message: msg}
  end
end

defmodule Cog.Repository.RelayGroups do
  @moduledoc """
  Behavioral API for interacting with relay groups. Prefer these
  functions over direct manipulation with 'Cog.Repo'.
  """

  alias Cog.Repo
  alias Cog.Models.RelayGroup
  alias Cog.Models.Relay
  alias Cog.Models.Bundle
  import Ecto.Query, only: [from: 2]

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
  Retrieves all relay groups based on a list of relay group names
  """
  @spec all_by_name(List.t) :: [%RelayGroup{}]
  def all_by_name(names) do
    Repo.all(from g in RelayGroup, where: g.name in ^names)
    |> Repo.preload([:bundles, :relays])
  end

  @doc """
  Retrieves a single relay group based on the id. The given id must a
  valid UUID.
  """
  @spec by_id(String.t) :: {:ok, %RelayGroup{}} | {:error, Ecto.Changeset.t} | {:error, Atom.t}
  def by_id(id) do
    with :ok <- valid_uuid(id) do
      case Repo.get(RelayGroup, id) do
        %RelayGroup{} = relay_group ->
          {:ok, Repo.preload(relay_group, [[bundles: :versions], :relays])}
        nil ->
          {:error, :not_found}
      end
    end
  end

  @doc """
  Like by_id/1 but raises an error if no results are returned
  """
  @spec by_id!(String.t) :: {:ok, %RelayGroup{}} | no_return()
  def by_id!(id) do
    valid_uuid!(id)
    Repo.get!(RelayGroup, id)
    |> Repo.preload([[bundles: :versions], :relays])
  end

  @doc """
  Retrieves a single relay group based on it's name.
  """
  @spec by_name(String.t) :: {:ok, %RelayGroup{}} | {:error, :not_found}
  def by_name(name) do
    case Repo.get_by(RelayGroup, name: name) do
      %RelayGroup{} = relay_group ->
        {:ok, Repo.preload(relay_group, [:bundles, :relays])}
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
      relay_group
      |> RelayGroup.changeset(:delete)
      |> Repo.delete
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

  @doc """
  Adds bundles and relays to relay groups via a member spec.
  """
  @spec manage_association(%RelayGroup{}, Map.t)
    :: {:ok, %RelayGroup{}} |
       {:error, {:not_found, {Atom.t, List.t}}} |
       {:error, {:bad_id, {Atom.t, List.t}}}
  def manage_association(%RelayGroup{}=relay_group, member_spec) do
    Repo.transaction(fn() ->
      try do
        member_keys = Map.keys(member_spec)

        members_to_add = Enum.flat_map(member_keys, &lookup_or_fail(member_spec, [&1, "add"]))
        members_to_remove = Enum.flat_map(member_keys, &lookup_or_fail(member_spec, [&1, "remove"]))

        relay_group
        |> add(members_to_add)
        |> remove(members_to_remove)

        by_id!(relay_group.id)
      rescue
        e in Cog.ProtectedBundleError ->
          Repo.rollback({:protected_bundle, e.bundle})
      end
    end)
  end
  def manage_association(id, member_spec) do
    case by_id(id) do
      {:ok, relay_group} ->
        manage_association(relay_group, member_spec)
      error ->
        error
    end
  end

  defp lookup_or_fail(member_spec, [kind, _operation]=path) do
    names = get_in(member_spec, path) || []
    case lookup_all(kind, names) do
      {:ok, structs} -> structs
      {:error, reason} ->
        Repo.rollback(reason)
    end
  end

  defp lookup_all(_, []), do: {:ok, []} # Don't bother with a DB lookup
  defp lookup_all(kind, ids) when kind in ["relays", "bundles"] do

    type = kind_to_type(kind) # e.g. "relays" -> Relay

    # Since we are using ids we need to make sure that they are all valid UUIDs
    # before we query the db. Otherwise Ecto with crash with a CastError
    case good_ids?(ids) do
      true ->
        results = Repo.all(from t in type, where: t.id in ^ids)

        # make sure we got a result for each id given
        case length(results) == length(ids) do
          true ->
            # Each name corresponds to an entity in the database
            {:ok, results}
          false ->
            # We got at least one name that doesn't map to any existing
            # user or group. Find out what's missing and report back
            retrieved_ids = Enum.map(results, &Map.get(&1, :id))
            bad_ids = ids -- retrieved_ids
            {:error, {:not_found, {kind, bad_ids}}}
        end
      {false, bad_ids} ->
        {:error, {:bad_id, {kind, bad_ids}}}
    end
  end

  defp good_ids?(ids) do
    bad_ids = Enum.reduce(ids, [], fn(id, acc) ->
      case Ecto.UUID.cast(id) do
        {:ok, _id} ->
          acc
        :error ->
          [id | acc]
      end
    end)

    if length(bad_ids) > 0 do
      {false, bad_ids}
    else
      true
    end
  end

  defp add(relay_group, members) do
    Enum.each(members, &Groupable.add_to(&1, relay_group))
    relay_group
  end

  defp remove(relay_group, members) do
    Enum.each(members, &Groupable.remove_from(&1, relay_group))
    relay_group
  end

  # Given a member_spec key, return the underlying type
  defp kind_to_type("relays"), do: Relay
  defp kind_to_type("bundles"), do: Bundle

  defp valid_uuid(id) do
    if Cog.UUID.is_uuid?(id) do
      :ok
    else
      {:error, :bad_id}
    end
  end

  defp valid_uuid!(id) do
    case valid_uuid(id) do
      :ok -> :ok
      {:error, :bad_id} -> raise(__MODULE__.BadIdError, id)
    end
  end
end
