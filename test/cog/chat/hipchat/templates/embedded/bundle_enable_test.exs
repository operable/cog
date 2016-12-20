defmodule Cog.Chat.HipChat.Templates.Embedded.BundleEnableTest do
  use Cog.TemplateCase

  test "bundle-enable template" do
    data = %{"results" => [%{"name" => "foo",
                             "version" => "1.0.0"}]}
    expected = "Enabled bundle 'foo' version '1.0.0'"
    assert_rendered_template(:hipchat, :embedded, "bundle-enable", data, expected)
  end

  test "bundle-enable template with multiple inputs" do
    data = %{"results" => [%{"name" => "foo", "version" => "1.0.0"},
                           %{"name" => "bar", "version" => "2.0.0"},
                           %{"name" => "baz", "version" => "3.0.0"}]}

    expected = """
    Enabled bundle 'foo' version '1.0.0'<br/>
    Enabled bundle 'bar' version '2.0.0'<br/>
    Enabled bundle 'baz' version '3.0.0'
    """ |> String.replace("\n", "")

    assert_rendered_template(:hipchat, :embedded, "bundle-enable", data, expected)
  end

end
