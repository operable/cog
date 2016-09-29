defmodule Cog.Chat.HipChat.Templates.Embedded.AliasMoveTest do
  use Cog.TemplateCase

  test "alias-move template" do
    data = %{"results" => [%{"source" => %{"visibility" => "user",
                                           "name" => "awesome"},
                             "destination" => %{"visibility" => "site",
                                                "name" => "awesome"}}]}
    expected = "Successfully moved user:awesome to site:awesome"
    assert_rendered_template(:hipchat, :embedded, "alias-move", data, expected)
  end

  test "alias-move with multiple inputs" do
    data = %{"results" => [%{"source" => %{"visibility" => "user",
                                           "name" => "awesome"},
                             "destination" => %{"visibility" => "site",
                                                "name" => "awesome"}},
                           %{"source" => %{"visibility" => "user",
                                           "name" => "do_stuff"},
                             "destination" => %{"visibility" => "site",
                                                "name" => "do_stuff"}},
                           %{"source" => %{"visibility" => "user",
                                           "name" => "thingie"},
                             "destination" => %{"visibility" => "site",
                                                "name" => "dohickey"}}]}
    expected = "Successfully moved user:awesome to site:awesome<br/>" <>
      "Successfully moved user:do_stuff to site:do_stuff<br/>" <>
      "Successfully moved user:thingie to site:dohickey"
    assert_rendered_template(:hipchat, :embedded, "alias-move", data, expected)
  end

end
