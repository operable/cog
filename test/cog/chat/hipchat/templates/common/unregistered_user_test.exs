defmodule Cog.Chat.HipChat.Templates.Common.UnregisteredUserTest do
  use Cog.TemplateCase

  test "unregistered_user renders properly with user creators" do
    data = %{"handle" => "nobody",
             "mention_name" => "@nobody",
             "display_name" => "HipChat",
             "user_creators" => ["@larry", "@moe", "@curly"]}
    expected = "@nobody: I'm terribly sorry, but either I don't have a Cog account for you, or your " <>
      "HipChat chat handle has not been registered. Currently, only registered users can interact with me." <>
      "<br/><br/><br/>" <>
      "You'll need to ask a Cog administrator to fix this situation and to register your HipChat handle." <>
      "<br/><br/><br/>" <>
      "The following users can help you right here in chat:" <>
      "<br/><br/><br/>" <>
      "@larry<br/>@moe<br/>@curly"
    assert_rendered_template(:hipchat, :common, "unregistered-user", data, expected)
  end

  test "unregistered_user renders properly without user creators" do
    data = %{"handle" => "nobody",
             "mention_name" => "@nobody",
             "display_name" => "HipChat",
             "user_creators" => []}
    expected = "@nobody: I'm terribly sorry, but either I don't have a Cog account for you, or your " <>
      "HipChat chat handle has not been registered. Currently, only registered users can interact with me." <>
      "<br/><br/><br/>" <>
      "You'll need to ask a Cog administrator to fix this situation and to register your HipChat handle."
    assert_rendered_template(:hipchat, :common, "unregistered-user", data, expected)
  end


end
