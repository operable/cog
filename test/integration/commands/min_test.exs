defmodule Integration.Commands.MinTest do
  use Cog.AdapterCase, adapter: "test"

  setup do
    user = user("vanstee", first_name: "Patrick", last_name: "Van Stee")
    |> with_chat_handle_for("test")

    {:ok, %{user: user}}
  end

  test "basic min", %{user: user} do
    response = send_message(user, ~s(@bot: seed '[{"a": 1}, {"a": 3}, {"a": 2}]' | min))
    assert response == [%{a: 1}]
  end

  test "min by simple key", %{user: user} do
    response = send_message(user, ~s(@bot: seed '[{"a": 1}, {"a": 3}, {"a": 2}]' | min a))
    assert response == [%{a: 1}]
  end

  test "min by complex key", %{user: user} do
    response = send_message(user, ~s(@bot: seed '[{"a": {"b": 1}}, {"a": {"b": 3}}, {"a": {"b": 2}}]' | min a.b))
    assert response == [%{a: %{b: 1}}]
  end

  test "min by incorrect key", %{user: user} do
    response = send_message(user, ~s(@bot: seed '[{"a": {"b": 1}}, {"a": {"b": 3}}, {"a": {"b": 2}}]' | min c.d))
    assert_error_message_contains(response, "The path provided does not exist")
  end
end
