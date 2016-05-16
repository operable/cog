defmodule Cog.Repository.Users do
  @moduledoc """
  Behavioral API for interacting with users. Prefer these
  functions over direct manipulation with 'Cog.Repo'.
  """

  alias Cog.Repo
  alias Cog.Models.User

  @doc """
  Creates a new user given a map of attributes
  """
  @spec new(Map.t) :: {:ok, %User{}} | {:error, Ecot.Changeset.t}
  def new(attrs) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert
  end

  @doc """
  Retrieves all users
  """
  @spec all :: [%User{}]
  def all,
    do: Repo.all(User)

  @doc """
  Retrieves one user by name
  """
  @spec by_username(String.t) :: {:ok, %User{}} | {:error, :not_found}
  def by_username(username) do
    case Repo.get_by(User, username: username) do
      %User{}=user ->
        {:ok, user}
      nil ->
        {:error, :not_found}
    end
  end

  @doc """
  Retrieves one user by id. Must be a valid uuid.
  """
  @spec by_id(String.t) :: {:ok, %User{}} | {:error, :bad_id} | {:error, :not_found}
  def by_id(id) do
    if Cog.UUID.is_uuid?(id) do
      case Repo.get(User, id) do
        %User{}=user ->
          {:ok, user}
        nil ->
          {:error, :not_found}
      end
    else
      {:error, :bad_id}
    end
  end

  @doc """
  Deletes a user
  """
  @spec delete(%User{}) :: {:ok, %User{}} | {:error, :not_found}
  def delete(%User{}=user) do
    try do
      Repo.delete(user)
    rescue
      Ecto.StateModelError ->
        {:error, :not_found}
    end
  end

  @doc """
  Updates a user
  """
  @spec update(%User{}, Map.t) :: {:ok, %User{}} | {:error, Ecto.Changeset.t}
  def update(%User{}=user, attrs) do
    changeset = User.changeset(user, attrs)
    Repo.update(changeset)
  end
end
