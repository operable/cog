defmodule Cog.Chat.Slack.Templates.Common.SelfRegistrationTest do
  use Cog.TemplateCase

  test "self_registration_success renders properly" do
    data = %{"mention_name" => "@cog",
             "first_name" => "Cog",
             "username" => "cog"}
    expected = """
    @cog: Hello Cog! It's great to meet you! You're the proud owner of a shiny new Cog account named 'cog'.
    """ |> String.strip
    assert_rendered_template(:common, "self-registration-success", data, expected)
  end

  test "self_registration_failed renders properly" do
    data = %{"mention_name" => "@mystery_user",
             "display_name" => "Slack"}
    expected = """
    @mystery_user: Unfortunately I was unable to automatically create a Cog account for your Slack chat handle. Only users with Cog accounts can interact with me.

    You'll need to ask a Cog administrator to investigate the situation and set up your account.
    """ |> String.strip
    assert_rendered_template(:common, "self-registration-failed", data, expected)
  end

end
