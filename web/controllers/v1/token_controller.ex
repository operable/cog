defmodule Cog.V1.TokenController do
  use Cog.Web, :controller

  alias Cog.Models.EctoJson
  alias Cog.Models.Token
  alias Cog.Models.User
  alias Cog.Passwords

  def create(conn, params) do
    case validate_params(params) do
      {:ok, %{"password" => password} = params} ->
        case find_user(params) do
          {:ok, user} ->
            verify_password(user, conn, password)
          {:error, :not_found} ->
            Passwords.matches?(nil, "")

            conn
            |> put_status(:forbidden)
            |> json(%{errors: "Invalid credentials"})
        end
      {:error, :invalid_params} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{errors: "Must supply both username/email and password"})
    end
  end

  defp validate_params(%{"username" => username, "password" => password} = params)
      when not(is_nil(username)) and not(is_nil(password)) do
    {:ok, params}
  end

  defp validate_params(%{"email" => email, "password" => password} = params)
      when not(is_nil(email)) and not(is_nil(password)) do
    {:ok, params}
  end

  defp validate_params(_params) do
    {:error, :invalid_params}
  end

  defp find_user(%{"username" => username}) do
    case Repo.get_by(User, username: username) do
      %User{} = user ->
        {:ok, user}
      nil ->
        {:error, :not_found}
    end
  end

  defp find_user(%{"email" => email}) do
    case Repo.get_by(User, email_address: email) do
      %User{} = user ->
        {:ok, user}
      nil ->
        {:error, :not_found}
    end
  end

  defp find_user(_params) do
    {:error, :invalid_params}
  end

  defp verify_password(user, conn, password) do
    case Passwords.matches?(password, user.password_digest) do
      true ->
        bind_token_to_user(user, conn)
      false ->
        # try again after URI decoding password
        case Passwords.matches?(URI.decode(password), user.password_digest) do
          true ->
            bind_token_to_user(user, conn)
          false ->
            conn
            |> put_status(:forbidden)
            |> json(%{errors: "Invalid credentials"})
        end
    end
  end

  defp bind_token_to_user(user, conn) do
    token_value = Token.generate
    case Token.insert_new(user, %{value: token_value}) do
      {:ok, token} ->
        conn
        |> put_status(:created)
        |> json(EctoJson.render(token, envelope: :token, policy: :summary))
      {:error, changeset} ->
        # TODO: Is this an internal error or something that will never occurr?
        conn
        |> put_status(:unprocessable_entity)
        |> render(Cog.ChangesetView, "error.json", changeset: changeset)
    end
  end

end
