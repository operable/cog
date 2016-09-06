defmodule Integration.Commands.FilterTest do
  use Cog.AdapterCase, adapter: "test"

  setup do
    user = user("vanstee", first_name: "Patrick", last_name: "Van Stee")
    |> with_chat_handle_for("test")

    {:ok, %{user: user}}
  end

  test "filters a list of things based on a match", %{user: user} do
    command = """
    @bot: seed '[{"foo":{"bar":"stuff", "baz":"other stuff"}}, \
    {"foo": {"bar":"me", "baz": "not this stuff"}},
    {"foo": {"bar":"stuff", "baz":"more stuff"}}]' | \
    filter \
    --path="foo.bar" \
    --matches="stuff"
    """

    response = send_message(user, command)

    assert [%{foo: %{bar: "stuff",
                     baz: "other stuff"}},
            %{foo: %{bar: "stuff",
                     baz: "more stuff"}}] = response
  end

  test "filters a list of things based on a key", %{user: user} do
    command = """
    @bot: seed '[{"foo":{"bar":"stuff", "baz":"other stuff"}}, \
    {"foo": {"bar":"me", "baz": "now this stuff"}},
    {"foo": {"baz":"more stuff"}}]' | \
    filter \
    --path="foo.bar"
    """

    response = send_message(user, command)

    assert [%{foo: %{bar: "stuff",
                     baz: "other stuff"}},
            %{foo: %{bar: "me",
                     baz: "now this stuff"}}] = response
  end
end
