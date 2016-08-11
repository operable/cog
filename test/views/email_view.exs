defmodule Cog.EmailViewTest do
  use Cog.ConnCase, async: true

  test "reset_url generates the proper url" do
    Application.put_env(:cog, :password_reset_base_url, "http://example.com:4000/reset-password")

    url = Cog.EmailView.reset_url("aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")

    assert url == "http://example.com:4000/reset-password/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
  end

  test "reset_url is not shown if password_reset_base_url is not set" do
    Application.delete_env(:cog, :password_reset_base_url)

    assigns = [token: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"]
    email = Phoenix.View.render_to_string(Cog.EmailView, "reset_password.text", assigns)

    refute email =~ "reset your password using the webui"
  end

end
