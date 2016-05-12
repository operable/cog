defmodule Cog.Repository.Groups do
  @moduledoc """
  Behavioral API for interacting with user groups. Prefer these
  functions over direct manipulation with 'Cog.Repo'.
  """

  alias Cog.Repo
  alias Cog.Models.Group

  @doc """
  Creates a new user group given a map of attributes
  """
  @spec new(Map.t) :: {:ok, %Group{}} | {:error, Ecto.Changeset.t}
  def new(attrs) do
    %Group{}
    |> Group.changeset(attrs)
    |> Repo.insert
  end

  @doc """
  Retrieves all user groups
  """
  @spec all :: [%Group{}]
  def all,
    do: Repo.all(Group) |> Repo.preload([:direct_user_members, :direct_group_members, :roles])

  @doc """
  Retrieves a single user group based on the id. The given id must be
  a valid UUID.
  """
  @spec by_id(String.t) :: {:ok, %Group{}} | {:error, Ecto.Changeset.t} | {:error, Atom.t}
  def by_id(id) do
    if Cog.UUID.is_uuid?(id) do
      case Repo.get(Group, id) do
        %Group{} = group ->
          group = Repo.preload(group, [:direct_user_members, :direct_group_members, :roles])
          {:ok, group}
        nil ->
          {:error, :not_found}
      end
    else
      {:error, :bad_id}
    end
  end

  @doc """
  Deletes a user group
  """
  @spec delete(%Group{}) :: {:ok, %Group{}} | {:error, Ecto.Changeset.t} | {:error, Atom.t}
  def delete(%Group{}=group) do
    try do
      Repo.delete(group)
    rescue
      Ecto.StaleModelError ->
        {:error, :not_found}
    end
  end

  @doc """
  Updates a user group
  """
  @spec update(%Group{}, Map.t) :: {:ok, %Group{}} | {:error, Ecto.Changeset.t}
  def update(%Group{}=group, attrs) do
    changeset = Group.changeset(group, attrs)
    Repo.update(changeset)
  end

end
