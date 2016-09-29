defmodule Cog.Chat.HipChat.Templates.Embedded.AliasCreateTest do
  use Cog.TemplateCase

  test "alias-create template" do
    data = %{"results" => [%{"name" => "awesome_alias"}]}
    expected = "Alias 'user:awesome_alias' has been created"
    assert_rendered_template(:hipchat, :embedded, "alias-create", data, expected)
  end

  test "alias-create with multiple inputs" do
    data = %{"results" => [%{"name" => "awesome_alias"},
                           %{"name" => "another_awesome_alias"},
                           %{"name" => "wow_neat"}]}
    expected = "Alias 'user:awesome_alias' has been created<br/>" <>
      "Alias 'user:another_awesome_alias' has been created<br/>" <>
      "Alias 'user:wow_neat' has been created"

    assert_rendered_template(:hipchat, :embedded, "alias-create", data, expected)
  end
end
