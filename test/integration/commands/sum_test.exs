defmodule Integration.Commands.SumTest do
  use Cog.AdapterCase, adapter: "test"


  setup do
    user = user("jfrost", first_name: "Jim", last_name: "Frost")
    |> with_chat_handle_for("test")

    {:ok, %{user: user}}
  end

  test "basic summing", %{user: user} do
    [four] = send_message(user, ~s(@bot: sum 2 2))
             |> decode_payload
    assert four.sum == "4.0"

    [n_seven] = send_message(user, ~s(@bot: sum 2 "-9"))
                |> decode_payload
    assert n_seven.sum == "-7.0"

    [three_hundred] = send_message(user, ~s(@bot: sum 2 24 57 3.7 226.78))
                      |> decode_payload
    assert three_hundred.sum == "313.48"
  end
end
