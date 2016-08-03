defmodule Cog.V1.PasswordResetController do
  use Cog.Web, :controller

  alias Cog.Repository.Users

  def create(conn, %{"email_address" => email_address}) do
    case Users.by_email(email_address) do
      {:ok, user} ->
        Users.request_password_reset(user)
        put_status(conn, :ok)
      _ ->
        put_status(conn, :ok)
    end
  end

  def update(_conn, _params) do
  end

end
