defmodule Cog.Chat.Slack.Templates.Embedded.AliasMoveTest do
  use Cog.TemplateCase

  test "alias-move template" do
    data = %{"results" => [%{"source" => %{"visibility" => "user",
                                           "name" => "awesome"},
                             "destination" => %{"visibility" => "site",
                                                "name" => "awesome"}}]}
    expected = "Moved alias 'user:awesome' to 'site:awesome'"
    assert_rendered_template(:slack, :embedded, "alias-move", data, expected)
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
    expected = """
    Moved alias 'user:awesome' to 'site:awesome'
    Moved alias 'user:do_stuff' to 'site:do_stuff'
    Moved alias 'user:thingie' to 'site:dohickey'
    """ |> String.strip

    assert_rendered_template(:slack, :embedded, "alias-move", data, expected)
  end

end
