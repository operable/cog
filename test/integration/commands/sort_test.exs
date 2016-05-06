defmodule Integration.SortTest do
  use Cog.AdapterCase, adapter: "test"

  setup do
    user = user("jfrost", first_name: "Jim", last_name: "Frost")
    |> with_chat_handle_for("test")
    |> with_permission("operable:manage_commands")

    {:ok, %{user: user}}
  end

  test "basic sorting", %{user: user} do
    response = send_message(user, ~s(@bot: seed '[{"a": 1}, {"a": 3}, {"a": 2}]' | sort))
    assert_payload(response, [%{a: 1}, %{a: 2}, %{a: 3}])
  end

  test "sorting in descending order", %{user: user} do
    response = send_message(user, ~s(@bot: seed '[{"a": 1}, {"a": 3}, {"a": 2}]' | sort --desc))
    assert_payload(response, [%{a: 3}, %{a: 2}, %{a: 1}])
  end

  test "sorting by specific fields", %{user: user} do
    response = send_message(user, ~s(@bot: seed '[{"a": 3, "b": 4}, {"a": 1, "b": 4}, {"a": 2, "b": 6}]' | sort b a))
    assert_payload(response, [%{a: 1, b: 4}, %{a: 3, b: 4}, %{a: 2, b: 6}])
  end
end
