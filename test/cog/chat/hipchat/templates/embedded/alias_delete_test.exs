defmodule Cog.Chat.HipChat.Templates.Embedded.AliasDeleteTest do
  use Cog.TemplateCase

  test "alias-delete template" do
    data = %{"results" => [%{"visibility" => "user", "name" => "awesome_alias"}]}
    expected = "Deleted 'user:awesome_alias'"
    assert_rendered_template(:hipchat, :embedded, "alias-delete", data, expected)
  end

  test "alias-delete with multiple inputs" do
    data = %{"results" => [%{"visibility" => "user", "name" => "awesome_alias"},
                           %{"visibility" => "user", "name" => "another_awesome_alias"},
                           %{"visibility" => "site", "name" => "wow_neat"}]}
    expected = "Deleted 'user:awesome_alias'<br/>" <>
      "Deleted 'user:another_awesome_alias'<br/>" <>
      "Deleted 'site:wow_neat'"
    assert_rendered_template(:hipchat, :embedded, "alias-delete", data, expected)
  end

end
