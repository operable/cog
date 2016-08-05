defmodule Cog.V1.PasswordResetController do
  use Cog.Web, :controller

  alias Cog.Repository.Users

  def create(conn, %{"email_address" => email_address}) do
    case Users.by_email(email_address) do
      {:ok, user} ->
        case Users.request_password_reset(user) do
          {:ok, _} ->
            send_resp(conn, :no_content, "")
          _ ->
            send_resp(conn, :internal_server_error, "")
        end
      _ ->
        send_resp(conn, :ok, "")
    end
  end

  def update(conn, %{"id" => id, "password" => password}) do
    case Users.reset_password(id, password) do
      {:ok, user} ->
        render(conn, Cog.V1.UserView, "show.json", user: user)
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{errors: "Password reset token not found"})
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(Cog.ChangesetView, "error.json", changeset: changeset)
    end
  end

end
