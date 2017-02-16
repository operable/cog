defmodule Cog.V1.PasswordResetController do
  use Cog.Web, :controller
  require Logger

  alias Cog.Repository.Users

  def create(conn, %{"email_address" => email_address}) do
    with {:ok, user} <- Users.by_email(email_address),
         {:ok, _} <- Users.request_password_reset(user) do
      send_resp(conn, :no_content, "")
    else
      {:error, :not_found} ->
        Logger.warn("Unknown email address sent for password reset")
        # We still return no_content here as an anti-phishing measure.
        # We don't want folks spamming this endpoint to find valid email
        # addresses.
        send_resp(conn, :no_content, "")
      {:error, {:not_configured, error}} ->
        Logger.warn("Email support has not been properly configured: #{inspect error}")
        conn
        |> put_status(:internal_server_error)
        |> json(%{errors: ["Password resets have been disabled or are not properly configured."]})
      {:error, error} ->
        Logger.warn("Failed to generate password reset: #{inspect error}")
        send_resp(conn, :internal_server_error, "")
    end
  end

  def update(conn, %{"id" => id, "password" => password}) do
    case Users.reset_password(id, password) do
      {:ok, _user} ->
        send_resp(conn, :no_content, "")
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{errors: ["Invalid password reset token."]})
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(Cog.ChangesetView, "error.json", changeset: changeset)
    end
  end

end
