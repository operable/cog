defmodule Cog.Chat.Slack.Templates.Embedded.AliasCreateTest do
  use Cog.TemplateCase

  test "alias-create template" do
    data = %{"results" => [%{"name" => "awesome_alias"}]}
    expected = "Alias 'user:awesome_alias' has been created"
    assert_rendered_template(:slack, :embedded, "alias-create", data, expected)
  end

  test "alias-create with multiple inputs" do
    data = %{"results" => [%{"name" => "awesome_alias"},
                           %{"name" => "another_awesome_alias"},
                           %{"name" => "wow_neat"}]}
    expected = """
    Alias 'user:awesome_alias' has been created
    Alias 'user:another_awesome_alias' has been created
    Alias 'user:wow_neat' has been created
    """ |> String.strip

    assert_rendered_template(:slack, :embedded, "alias-create", data, expected)
  end
end
