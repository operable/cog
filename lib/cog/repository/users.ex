defmodule Cog.Repository.Users do
  @moduledoc """
  Behavioral API for interacting with users. Prefer these
  functions over direct manipulation with 'Cog.Repo'.
  """

  alias Cog.Repo
  alias Cog.Models.User
  import Ecto.Query, only: [from: 1, from: 2]

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
  Retrieves all users with a username in usernames. If only some
  users can be found returns {:some, users, not_found_usernames}
  """
  @spec all_with_username([String.t]) :: {:ok, [%User{}]} | {:some, [%User{}], [String.t]} | {:error, :not_found}
  def all_with_username(usernames) do
    case Repo.all(from u in User, where: u.username in ^usernames) do
      users when is_list(users) ->
        if length(users) == length(usernames) do
          {:ok, users}
        else
          not_found_usernames = usernames -- Enum.map(users, &(&1.username))
          {:some, users, not_found_usernames}
        end
      nil ->
        {:error, :not_found}
    end
  end

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
    Repo.delete(user)
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
