defmodule Cog.Repository.Users do
  @moduledoc """
  Behavioral API for interacting with users. Prefer these
  functions over direct manipulation with 'Cog.Repo'.
  """

  alias Cog.Repo
  alias Cog.Models.User
  alias Cog.Models.ChatHandle
  alias Cog.Models.PasswordReset
  import Ecto.Query, only: [from: 2]

  @doc """
  Creates a new user given a map of attributes
  """
  @spec new(Map.t) :: {:ok, %User{}} | {:error, Ecto.Changeset.t}
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
  Retrieves one user by email
  """
  @spec by_email(String.t) :: {:ok, %User{}} | {:error, :not_found}
  def by_email(email) do
    case Repo.get_by(User, email_address: email) do
      %User{}=user ->
        {:ok, user}
      nil ->
        {:error, :not_found}
    end
  end

  @doc """
  Retrieves one user by chat handle
  """
  @spec by_chat_handle(String.t, String.t) :: {:ok, %User{}} | {:error, :not_found}
  def by_chat_handle(handle, provider_name) do
    case Repo.one(from u in User,
                  join: ch in ChatHandle, on: ch.user_id == u.id,
                  join: cp in assoc(ch, :chat_provider),
                  where: ch.handle == ^handle,
                  where: cp.name == ^provider_name) do
      nil ->
        {:error, :not_found}
      user ->
        {:ok, user}
    end
  end

  @doc """
  Determines if a given username has been registered
  """
  def is_username_available?(username) do
    Repo.one!(from u in User,
              where: u.username == ^username,
              select: count(u.id)) == 0
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

  @doc """
  Creates a password reset request
  """
  @spec request_password_reset(%User{}) :: :ok | {:error, any()}
  def request_password_reset(%User{id: user_id, email_address: email_address}) do
    Repo.transaction(fn ->
      password_reset = PasswordReset.changeset(%PasswordReset{}, %{user_id: user_id})
      |> Repo.insert!

      Cog.Email.reset_password(email_address, password_reset.id)
      |> Cog.Mailer.deliver_later

      password_reset
    end)
  end

  @doc """
  Resets a user's password if a password reset exists with the given token
  """
  @spec reset_password(String.t, String.t) :: {:ok, %User{}} | {:error, :not_found} | {:error, Ecto.Changeset.t}
  def reset_password(token, password) do
    case Repo.get(PasswordReset, token) |> Repo.preload([:user]) do
      nil ->
        {:error, :not_found}
      %{user: user}=password_reset ->
        Repo.transaction(fn ->
          with {:ok, updated_user} <- update(user, %{password: password}),
               {:ok, _}            <- Repo.delete(password_reset) do
             updated_user
          else
            {:error, error} ->
              Repo.rollback(error)
          end
        end)
    end
  end

end
