defmodule Integration.RedirectTest do
  use Cog.AdapterCase, adapter: "test"

  setup do
    user = user("vanstee", first_name: "Patrick", last_name: "Van Stee")
    |> with_chat_handle_for("Test")

    {:ok, %{user: user}}
  end

  test "redirecting to 'here'", %{user: user} do
    response = send_message(user, "@bot: operable:echo test_here > here")
    assert %{"id" => _,
             "response" => "test_here",
             "room" => %{"id" => "general",
                         "name" => "general"}} = response
  end

  test "redirection to '#general'", %{user: user} do
    response = send_message(user, "@bot: operable:echo test_general > #general")
    assert %{"id" => _,
             "response" => "test_general",
             "room" => %{"id" => "general",
                         "name" => "general"}} = response
  end

  test "redirection to 'general'", %{user: user} do
    response = send_message(user, "@bot: operable:echo test_general > general")
    assert  %{"id" => _,
              "response" => "test_general",
              "room" => %{"id" => "general",
                          "name" => "general"}} = response
  end

  test "redirection to 'me'", %{user: user} do
    response = send_message(user, "@bot: operable:t-echo test_me > me")
    assert %{"id" => _,
             "response" => "test_me",
             "room" => %{"id" => "channel1"}} = response
  end

  test "redirection to 'vanstee'", %{user: user} do
    response = send_message(user, "@bot: operable:echo test_vanstee > vanstee")
    assert %{"id" => _,
             "response" => "test_vanstee",
             "room" => %{"id" => "vanstee",
                         "name" => "vanstee"}} = response
  end

  test "redirection to '@vanstee'", %{user: user} do
    response = send_message(user, "@bot: operable:echo test_vanstee > @vanstee")

    assert %{"id" => _,
             "response" => "test_vanstee",
             "room" => %{"id" => "vanstee",
                         "name" => "direct"}} = response
  end

  test "redirection to 'chat://@vanstee'", %{user: user} do
    response = send_message(user, "@bot: operable:echo test_vanstee > chat://@vanstee")
    assert %{"id" => _,
             "response" => "test_vanstee",
             "room" => %{"id" => "vanstee",
                         "name" => "direct"}} = response
  end

  test "redirection to 'chat://#general'", %{user: user} do
    response = send_message(user, "@bot: operable:echo test_general > chat://#general")
    assert %{"id" => _,
             "response" => "test_general",
             "room" => %{"id" => "general",
                         "name" => "general"}} = response
  end

end
