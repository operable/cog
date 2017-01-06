defmodule Cog.Chat.Slack.Templates.Embedded.InfoTest do
  use Cog.TemplateCase

  test "info template" do
    data = %{"results" => [%{"embedded_bundle_version" => "0.18.0",
                             "elixir_version" => "1.3.4",
                             "cog_version" => "0.18.0",
                             "bundle_config_version" => 5}]}

    expected = """
    *Cog System Information*
    """ |> String.strip

    attachment = ["""
    *Cog Version:* 0.18.0
    *Embedded Bundle Version:* 0.18.0
    *Bundle Config Version:* 5
    *Elixir Version:* 1.3.4
    """] |> Enum.map(&String.strip/1)

    assert_rendered_template(:slack, :embedded, "info", data, {expected, attachment})
  end
end
