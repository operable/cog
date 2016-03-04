defmodule Integration.Commands.WhichTest do
  use Cog.AdapterCase, adapter: "test"
  alias Cog.Integration.Helpers

  setup do
    user = user("vanstee", first_name: "Patrick", last_name: "Van Stee")
    |> with_chat_handle_for("test")

    {:ok, %{user: user}}
  end

  test "an alias in the 'user' visibility", %{user: user} do
    expected_map = %{type: "alias", scope: "user", name: "my-new-alias", pipeline: "echo My New Alias"}

    send_message(user, "@bot: operable:alias new my-new-alias \"echo My New Alias\"")

    response = send_message(user, "@bot: operable:which my-new-alias")
    expected_response = Helpers.render_template("which", expected_map)
    assert response["data"]["response"] == expected_response
  end

  test "an alias in the 'site' visibility", %{user: user} do
    expected_map = %{type: "alias", scope: "site", name: "my-new-alias", pipeline: "echo My New Alias"}

    send_message(user, "@bot: operable:alias new my-new-alias \"echo My New Alias\"")
    send_message(user, "@bot: operable:alias mv my-new-alias site")

    response = send_message(user, "@bot: operable:which my-new-alias")
    expected_response = Helpers.render_template("which", expected_map)
    assert response["data"]["response"] == expected_response
  end

  test "a command", %{user: user} do
    expected_map = %{type: "command", scope: "operable", name: "alias"}

    response = send_message(user, "@bot: operable:which alias")
    expected_response = Helpers.render_template("which", expected_map)
    assert response["data"]["response"] == expected_response
  end

  test "an unknown", %{user: user} do
    expected_map = %{not_found: true}

    response = send_message(user, "@bot: operable:which foo")
    expected_response = Helpers.render_template("which", expected_map)
    assert response["data"]["response"] == expected_response
  end

end
