defmodule Integration.Commands.MaxTest do
  use Cog.AdapterCase, adapter: "test"

  setup do
    user = user("vanstee", first_name: "Patrick", last_name: "Van Stee")
    |> with_chat_handle_for("test")

    {:ok, %{user: user}}
  end

  test "Max from a set of integers", %{user: user} do
    response = send_message(user, "@bot: operable:max 49 9 2 2")

    [payload] = decode_payload(response)

    assert payload.max == 49
  end

  test "Max from a set of floats", %{user: user} do
    response = send_message(user, "@bot: operable:max 0.48 0.2 1.8 3548.4 0.078")

    [payload] = decode_payload(response)

    assert payload.max == 3548.4
  end

  test "Max from a set of words", %{user: user} do
    response = send_message(user, "@bot: operable:max apple ball car zebra")

    [payload] = decode_payload(response)

    assert payload.max == "zebra"
  end
end
