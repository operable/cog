defmodule Cog.V1.TokenController do
  use Cog.Web, :controller

  alias Cog.Models.EctoJson
  alias Cog.Models.Token
  alias Cog.Models.User
  alias Cog.Passwords

  def create(conn, %{"username" => username,
                     "password" => password}) do
    case Repo.get_by(User, username: username) do
      %User{} = user ->
        verify_password(user, conn, password)
      nil ->
        Passwords.matches?(nil, "")
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Invalid username/password"})
    end
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
            |> json(%{error: "Invalid username/password"})
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
