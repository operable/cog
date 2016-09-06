defmodule Integration.Commands.WhichTest do
  use Cog.AdapterCase, adapter: "test"

  setup do
    user = user("vanstee", first_name: "Patrick", last_name: "Van Stee")
    |> with_chat_handle_for("test")

    {:ok, %{user: user}}
  end

  test "an alias in the 'user' visibility", %{user: user} do
    send_message(user, "@bot: operable:alias create my-new-alias \"echo My New Alias\"")

    response = send_message(user, "@bot: operable:which my-new-alias")

    assert response == [%{type: "alias",
                          scope: "user",
                          name: "my-new-alias",
                          pipeline: "echo My New Alias"}]
  end

  test "an alias in the 'site' visibility", %{user: user} do
    send_message(user, "@bot: operable:alias create my-new-alias \"echo My New Alias\"")
    send_message(user, "@bot: operable:alias move my-new-alias site")

    response = send_message(user, "@bot: operable:which my-new-alias")

    assert response == [%{type: "alias",
                          scope: "site",
                          name: "my-new-alias",
                          pipeline: "echo My New Alias"}]
  end

  test "a command", %{user: user} do
    response = send_message(user, "@bot: operable:which alias")

    assert response == [%{type: "command",
                          scope: "operable",
                          name: "alias"}]
  end

  test "an unknown", %{user: user} do
    response = send_message(user, "@bot: operable:which foo")

    assert response == [%{not_found: true}]
  end

end
