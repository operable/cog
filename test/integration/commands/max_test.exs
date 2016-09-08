defmodule Integration.MaxTest do
  use Cog.AdapterCase, adapter: "test"

  setup do
    user = user("jfrost", first_name: "Jim", last_name: "Frost")
    |> with_chat_handle_for("test")

    {:ok, %{user: user}}
  end

  test "basic max", %{user: user} do
    response = send_message(user, ~s(@bot: seed '[{"a": 1}, {"a": 3}, {"a": 2}]' | max))
    assert response == [%{a: 3}]
  end

  test "max by simple key", %{user: user} do
    response = send_message(user, ~s(@bot: seed '[{"a": 1}, {"a": 3}, {"a": 2}]' | max a))
    assert response == [%{a: 3}]
  end

  test "max by complex key", %{user: user} do
    response = send_message(user, ~s(@bot: seed '[{"a": {"b": 1}}, {"a": {"b": 3}}, {"a": {"b": 2}}]' | max a.b))
    assert response == [%{a: %{b: 3}}]
  end

  test "max by incorrect key", %{user: user} do
    response = send_message(user, ~s(@bot: seed '[{"a": {"b": 1}}, {"a": {"b": 3}}, {"a": {"b": 2}}]' | min c.d))
    assert_error_message_contains(response, "The path provided does not exist")
  end
end
