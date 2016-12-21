defmodule Cog.Chat.Slack.Templates.Embedded.AliasListTest do
  use Cog.TemplateCase

  test "alias-list template" do
    data = %{"results" => [%{"visibility" => "user",
                             "name" => "awesome_alias",
                             "pipeline" => "echo 'awesome!'"},
                           %{"visibility" => "user",
                             "name" => "another_awesome_alias",
                             "pipeline" => "echo 'more awesome!'"},
                           %{"visibility" => "site",
                             "name" => "wow_neat",
                             "pipeline" => "echo 'wow, neat!'"}]}

    attachments = ["user:awesome_alias", "user:another_awesome_alias", "site:wow_neat"]

    assert_rendered_template(:slack, :embedded, "alias-list", data, {"", attachments})
  end

end
