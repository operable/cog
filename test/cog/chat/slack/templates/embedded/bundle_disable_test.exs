defmodule Cog.Chat.Slack.Templates.Embedded.BundleDisableTest do
  use Cog.TemplateCase

  test "bundle-disable template" do
    data = %{"results" => [%{"name" => "foo",
                             "version" => "1.0.0"}]}
    expected = ~s(Disabled bundle 'foo' version '1.0.0')
    assert_rendered_template(:slack, :embedded, "bundle-disable", data, expected)
  end

  test "bundle-disable template with multiple inputs" do
    data = %{"results" => [%{"name" => "foo", "version" => "1.0.0"},
                           %{"name" => "bar", "version" => "2.0.0"},
                           %{"name" => "baz", "version" => "3.0.0"}]}
    expected = """
    Disabled bundle 'foo' version '1.0.0'
    Disabled bundle 'bar' version '2.0.0'
    Disabled bundle 'baz' version '3.0.0'
    """ |> String.strip
    assert_rendered_template(:slack, :embedded, "bundle-disable", data, expected)
  end

end
