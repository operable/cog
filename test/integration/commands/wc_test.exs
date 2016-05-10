defmodule Integration.Commands.WcTest do
  use Cog.AdapterCase, adapter: "test"

  setup do
    user = user("jfrost", first_name: "Jim", last_name: "Frost")
    |> with_chat_handle_for("test")

    {:ok, %{user: user}}
  end

  test "counting words", %{user: user} do
    response = send_message(user, ~s(@bot: wc --words "Hey, what will we do today?"))

    [count] = decode_payload(response)

    assert count.words == 6
  end

  test "counting lines", %{user: user} do
    response = send_message(user, ~s(@bot: wc --lines "From time to time\n The clouds give rest\n To the moon-beholders."))

    [count] = decode_payload(response)

    assert count.lines == 3
  end
end
