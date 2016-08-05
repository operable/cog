defmodule Cog.Email.PasswordReset.Test do
  @moduledoc """
  Email tests for resetting user passwords
  """

  use Cog.EmailCase
  alias Cog.Repository.Users

  test "password reset emails are sent" do
    {:ok, user} = Users.new(%{username: "Bob",
                              email_address: "bob@example.com",
                              password: "password"})

    {:ok, password_reset} = Users.request_password_reset(user)

    assert_delivered_email(Cog.Email.reset_password(user.email_address, password_reset.id))
  end
end
