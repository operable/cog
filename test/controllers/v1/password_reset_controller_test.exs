defmodule Cog.V1.PasswordResetController.Test do
  use Cog.ConnCase

  alias Cog.Repository.Users
  alias Cog.Repo
  alias Cog.Models.PasswordReset
  import Ecto.Query, only: [from: 2]

  setup_all context do
    {:ok, Map.merge(context, %{conn: Phoenix.ConnTest.build_conn()})}
  end

  setup context do
    {:ok, user} = Users.new(%{username: "Bob",
                              email_address: "bob@example.com",
                              password: "password"})
    {:ok, Map.merge(context, %{user: user})}
  end

  test "password resets are generated", %{conn: conn, user: user} do
    resp = post(conn, password_reset_path(conn, :create), email_address: user.email_address)

    assert resp.status == 204
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

  test "if multiple resets are requested, only the latest is kept", %{conn: conn, user: user} do
    # Request the initial reset
    resp = post(conn, password_reset_path(conn, :create), email_address: user.email_address)

    assert resp.status == 204

    # Setup a query to get resets by user_id
    query = from(pr in PasswordReset, where: pr.user_id == ^user.id)

    # Save the original reset
    original_reset = Repo.one!(query)

    # Make another request
    resp = post(conn, password_reset_path(conn, :create), email_address: user.email_address)

    assert resp.status == 204

    # Query again
    new_reset = Repo.one!(query)

    # Make sure the resets aren't the same
    refute original_reset.id == new_reset.id
  end
end
