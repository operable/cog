defmodule Integration.Commands.SeedTest do
  use Cog.AdapterCase, adapter: "test"


  setup do
    user = user("jfrost", first_name: "Jim", last_name: "Frost")
    |> with_chat_handle_for("test")

    {:ok, %{user: user}}
  end

  test "basic seeding", %{user: user} do
    response = send_message(user, ~s(@bot: seed '[{"a": 1}, {"a": 3}, {"a": 2}]'))
    assert [%{a: 1}, %{a: 3}, %{a: 2}] = response
  end

end
