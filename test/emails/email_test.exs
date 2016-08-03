defmodule Cog.Email.Email.Test do
  @moduledoc """
  Simple smoke test to make sure that email is working properly.
  """

  use Cog.EmailCase
  alias Bamboo.Email

  test "emails can be sent" do
    test_email =
      Email.new_email(from: "noreply@example.com",
                      to: "bob@example.com",
                      subject: "Test Email",
                      text_body: "This is a test message.")
    Cog.Mailer.deliver_later(test_email)

    assert_delivered_email(test_email)
  end
end
