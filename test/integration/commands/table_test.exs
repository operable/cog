defmodule Integration.Commands.TableTest do
  use Cog.AdapterCase, adapter: "test"

  setup do
    user = user("vanstee", first_name: "Patrick", last_name: "Van Stee")
    |> with_chat_handle_for("test")

    {:ok, %{user: user}}
  end

  # TODO: Figure out a better way of testing this without a template
  test "displaying data in a table", %{user: user} do
    response = send_message(user, ~s<@bot: seed '[{"foo": "foo1", "bar": "bar1", "baz": "baz1"}, {"foo": "foo2", "bar": "bar2", "baz": "baz2"}]' | table --fields "foo,bar,baz">)
    assert response["data"]["response"] == """
    {
      "table": "foo   bar   baz \\nfoo1  bar1  baz1\\nfoo2  bar2  baz2"
    }
    """ |> String.rstrip
  end
end
