defmodule Integration.Commands.SleepTest do
  use Cog.AdapterCase, adapter: "test"

  setup do
    user = user("jfrost", first_name: "Jim", last_name: "Frost")
    |> with_chat_handle_for("test")

    {:ok, %{user: user}}
  end

  test "basic sleeping", %{user: user} do
    response = send_message(user, ~s(@bot: sleep 1 | echo Lasagna is done cooking!))
    assert response == "Lasagna is done cooking!"
  end
end
