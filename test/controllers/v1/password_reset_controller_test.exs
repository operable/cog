defmodule Cog.V1.PasswordResetController.Test do
  use Cog.ConnCase

  alias Cog.Repository.Users
  alias Cog.Repo
  alias Cog.Models.PasswordReset

  setup_all context do
    {:ok, Map.merge(context, %{conn: Phoenix.ConnTest.conn()})}
  end

  setup context do
    {:ok, user} = Users.new(%{username: "Bob",
                              email_address: "bob@example.com",
                              password: "password"})
    {:ok, Map.merge(context, %{user: user})}
  end

  test "password resets are generated", %{conn: conn, user: user} do
    resp = post(conn, password_reset_path(conn, :create), email_address: user.email_address)

    assert resp.status == 200
    Repo.get_by!(PasswordReset, user_id: user.id)
  end

  test "we can reset a password with the proper token", %{conn: conn, user: user} do
    # Make sure the user can get a token
    post(conn, token_path(conn, :create), username: user.username, password: user.password)
    |> json_response(201)

    # Then we'll create the password reset request
    {:ok, password_reset} = Users.request_password_reset(user)

    # Then update our password with the reset request
    put(conn, password_reset_path(conn, :update, password_reset.id), password: "new_password")

    # Try to get a token with the old password
    post(conn, token_path(conn, :create), username: user.username, password: user.password)
    |> json_response(403)

    # And finally see if we can get a token with the new password
    post(conn, token_path(conn, :create), username: user.username, password: "new_password")
    |> json_response(201)
  end
end
