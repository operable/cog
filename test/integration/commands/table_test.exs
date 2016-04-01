defmodule Integration.Commands.TableTest do
  use Cog.AdapterCase, adapter: "test"

  setup do
    user = user("vanstee", first_name: "Patrick", last_name: "Van Stee")
    |> with_chat_handle_for("test")

    {:ok, %{user: user}}
  end

  test "displaying data in a table", %{user: user} do
    response = send_message(user, ~s<@bot: seed '[{"foo": "foo1", "bar": "bar1", "baz": "baz1"}, {"foo": "foo2", "bar": "bar2", "baz": "baz2"}]' | table --fields "foo,bar,baz">)

    assert_payload(response, %{
      table: "foo   bar   baz \nfoo1  bar1  baz1\nfoo2  bar2  baz2"
    })
  end
end
