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
    expected = "Found 3 matching aliases.<br/><br/>" <>
      "Name: <pre>awesome_alias</pre><br/>" <>
      "Visibility: <pre>user</pre><br/>" <>
      "Pipeline: <pre>echo 'awesome!'</pre><br/><br/>" <>
      "Name: <pre>another_awesome_alias</pre><br/>" <>
      "Visibility: <pre>user</pre><br/>" <>
      "Pipeline: <pre>echo 'more awesome!'</pre><br/><br/>" <>
      "Name: <pre>wow_neat</pre><br/>" <>
      "Visibility: <pre>site</pre><br/>" <>
      "Pipeline: <pre>echo 'wow, neat!'</pre>"

    assert_rendered_template(:hipchat, :embedded, "alias-list", data, expected)
  end

end
