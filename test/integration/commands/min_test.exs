defmodule Integration.Commands.MinTest do
  use Cog.AdapterCase, adapter: "test"

  setup do
    user = user("vanstee", first_name: "Patrick", last_name: "Van Stee")
    |> with_chat_handle_for("test")

    {:ok, %{user: user}}
  end

  test "Min from a set of integers", %{user: user} do
    response = send_message(user, "@bot: operable:min 49 9 2 2")

    [payload] = decode_payload(response)

    assert payload.min == 2
  end

  test "Min from a set of floats", %{user: user} do
    response = send_message(user, "@bot: operable:min 0.48 0.2 1.8 3548.4 0.078")

    [payload] = decode_payload(response)

    assert payload.min == 0.078
  end

  test "Min from a set of words", %{user: user} do
    response = send_message(user, "@bot: operable:min apple ball car zebra")

    [payload] = decode_payload(response)

    assert payload.min == "apple"
  end
end
