defmodule Integration.RedirectTest do
  use Cog.AdapterCase, adapter: "test"

  setup do
    user = user("vanstee", first_name: "Patrick", last_name: "Van Stee")
    |> with_chat_handle_for("Test")

    {:ok, %{user: user}}
  end

  test "redirecting to 'here'", %{user: user} do
    response = send_message(user, "@bot: operable:echo test_here > here")

    expected_response = %{"adapter" => "test",
                          "response" => "test_here",
                          "room" => %{"id" => 1, "name" => "general"}}

    assert response["data"] == expected_response
  end

  test "redirection to '#general'", %{user: user} do
    response = send_message(user, "@bot: operable:echo test_general > #general")

    expected_response = %{"adapter" => "test",
                          "response" => "test_general",
                          "room" => %{"id" => 1, "name" => "general"}}

    assert response["data"] == expected_response
  end

  test "redirection to 'general'", %{user: user} do
    response = send_message(user, "@bot: operable:echo test_general > general")

    expected_response = %{"adapter" => "test",
                          "response" => "test_general",
                          "room" => %{"id" => 1, "name" => "general"}}

    assert response["data"] == expected_response
  end

  test "redirection to 'me'", %{user: user} do
    response = send_message(user, "@bot: operable:t-echo test_me > me")

    expected_response = %{"adapter" => "test",
                          "response" => "test_me",
                          "room" => %{"id" => "channel1"}}

    assert response["data"] == expected_response
  end

  test "redirection to 'vanstee'", %{user: user} do
    response = send_message(user, "@bot: operable:echo test_vanstee > vanstee")

    expected_response = %{"adapter" => "test",
                          "response" => "test_vanstee",
                          "room" => %{"id" => 1, "name" => "vanstee"}}

    assert response["data"] == expected_response
  end

  test "redirection to '@vanstee'", %{user: user} do
    response = send_message(user, "@bot: operable:echo test_vanstee > @vanstee")

    expected_response = %{"adapter" => "test",
                          "response" => "test_vanstee",
                          "room" => %{"id" => 1, "name" => "direct"}}

    assert response["data"] == expected_response
  end
end
