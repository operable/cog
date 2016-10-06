defmodule Cog.Test.Commands.EchoTest do
  use Cog.AdapterCase, adapter: "test"

  @moduletag :skip

  setup do
    user = user("vanstee", first_name: "Patrick", last_name: "Van Stee")
    |> with_chat_handle_for("test")

    {:ok, %{user: user}}
  end

  test "Repeats whatever it is passed", %{user: user} do
    response = send_message(user, "@bot: operable:echo this is nifty")
    assert response == "this is nifty"
  end

  test "serializes json when it's passed", %{user: user} do
    response = send_message(user, ~s(@bot: seed '{"foo": {"bar": "baz"}}' | echo $foo))
    assert response == %{bar: "baz"}
  end
end
