defmodule Cog.Chat.HipChat.Templates.Embedded.AliasListTest do
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
    expected = "Found 3 matching aliases.<br/><br/><br/>" <>
      "Name: <code>awesome_alias</code><br/>" <>
      "Visibility: <code>user</code><br/>" <>
      "Pipeline: <code>echo 'awesome!'</code><br/><br/><br/>" <>
      "Name: <code>another_awesome_alias</code><br/>" <>
      "Visibility: <code>user</code><br/>" <>
      "Pipeline: <code>echo 'more awesome!'</code><br/><br/><br/>" <>
      "Name: <code>wow_neat</code><br/>" <>
      "Visibility: <code>site</code><br/>" <>
      "Pipeline: <code>echo 'wow, neat!'</code>"

    assert_rendered_template(:hipchat, :embedded, "alias-list", data, expected)
  end

end
