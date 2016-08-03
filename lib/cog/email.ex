defmodule Cog.Email do
  use Bamboo.Phoenix, view: Cog.EmailView
  alias Bamboo.Email

  def reset_password(email_address, token) do
    Email.new_email(from: Application.fetch_env!(:cog, :email_from),
                    subject: "Cog - Password Reset Request",
                    to: email_address)
    |> render("reset_password.text", token: token)
  end
end
