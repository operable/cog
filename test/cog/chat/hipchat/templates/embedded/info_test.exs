defmodule Cog.Chat.HipChat.Templates.Embedded.InfoTest do
  use Cog.TemplateCase

  test "info template" do
    data = %{"results" => [%{"embedded_bundle_version" => "0.18.0",
                             "elixir_version" => "1.3.4",
                             "cog_version" => "0.18.0",
                             "bundle_config_version" => 5}]}

    expected = """
    <strong>Cog System Information</strong><br/>\
    <br/>\
    <strong>Cog Version:</strong> 0.18.0<br/>\
    <strong>Embedded Bundle Version:</strong> 0.18.0<br/>\
    <strong>Bundle Config Version:</strong> 5<br/>\
    <strong>Elixir Version:</strong> 1.3.4
    """ |> String.strip

    assert_rendered_template(:hipchat, :embedded, "info", data, expected)
  end
end
