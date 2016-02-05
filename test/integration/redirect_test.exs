defmodule Integration.RedirectTest do
  use Cog.AdapterCase, adapter: Cog.Adapters.Test

  setup do
    user = user("vanstee", first_name: "Patrick", last_name: "Van Stee")
    |> with_chat_handle_for("test")

    {:ok, %{user: user}}
  end

  test "redirecting to 'here'", %{user: user} do
    send_message user, "@bot: operable:echo test_here > here"

    response = %{"adapter" => "test",
                 "response" => "test_here",
                 "room" => %{"id" => 1, "name" => "general"}}

    assert_payload response
  end

  test "redirection to '#general'", %{user: user} do
    send_message user, "@bot: operable:echo test_general > #general"

    response = %{"adapter" => "test",
                 "response" => "test_general",
                 "room" => %{"id" => 1, "name" => "general"}}

    assert_payload response
  end

  test "redirection to 'general'", %{user: user} do
    send_message user, "@bot: operable:echo test_general > general"

    response = %{"adapter" => "test",
                 "response" => "test_general",
                 "room" => %{"id" => 1, "name" => "general"}}

    assert_payload response
  end

  test "redirection to 'me'", %{user: user} do
    send_message user, "@bot: operable:t-echo test_me > me"

    response = %{"adapter" => "test",
                 "response" => "test_me",
                 "room" => %{"id" => "channel1"}}

    assert_payload response
  end

  test "redirection to 'vanstee'", %{user: user} do
    send_message user, "@bot: operable:echo test_vanstee > vanstee"

    response = %{"adapter" => "test",
                 "response" => "test_vanstee",
                 "room" => %{"id" => 1, "name" => "vanstee"}}

    assert_payload response
  end

  test "redirection to '@vanstee'", %{user: user} do
    send_message user, "@bot: operable:echo test_vanstee > @vanstee"

    response = %{"adapter" => "test",
                 "response" => "test_vanstee",
                 "room" => %{"id" => 1, "name" => "direct"}}

    assert_payload response
  end
end
