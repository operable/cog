defmodule Integration.RedirectTest do
  use Cog.AdapterCase, adapter: "test"
  alias Cog.Snoop
  require Logger

  setup do
    user = user("vanstee", first_name: "Patrick", last_name: "Van Stee")
    |> with_chat_handle_for("test")

    {:ok, snoop} = Snoop.adapter_traffic
    {:ok, %{user: user,
            snoop: snoop}}
  end

  @here "I_AM_HERE"

  defp chat(user, text),
    do: send_message(user, @here, text)

  test "redirecting to 'here'", %{user: user, snoop: snoop} do
    chat(user, "@bot: operable:echo test_here > here")
    assert ["test_here"] = Snoop.loop_until_received(snoop, provider: "test", target: @here)
  end

  test "redirection to '#general'", %{user: user, snoop: snoop} do
    chat(user, "@bot: operable:echo test_general > #general")
    Snoop.assert_no_message_received(snoop, provider: "test", target: @here)
    assert ["test_general"] = Snoop.loop_until_received(snoop, provider: "test", target: "#general")
  end

  test "redirection to 'me'", %{user: user, snoop: snoop} do
    chat(user, "@bot: operable:t-echo test_me > me")
    Snoop.assert_no_message_received(snoop, provider: "test", target: @here)
    assert ["test_me"] = Snoop.loop_until_received(snoop, provider: "test", target: "vanstee")
  end

  test "redirection to '@vanstee'", %{user: user, snoop: snoop} do
    chat(user, "@bot: operable:echo test_vanstee > @vanstee")
    Snoop.assert_no_message_received(snoop, provider: "test", target: @here)
    assert ["test_vanstee"] = Snoop.loop_until_received(snoop, provider: "test", target: "@vanstee")
  end

  test "redirection to 'chat://@vanstee'", %{user: user, snoop: snoop} do
    chat(user, "@bot: operable:echo test_vanstee > chat://@vanstee")
    Snoop.assert_no_message_received(snoop, provider: "test", target: @here)
    assert ["test_vanstee"] = Snoop.loop_until_received(snoop, provider: "test", target: "@vanstee")
  end

  test "redirection to 'chat://#general'", %{user: user, snoop: snoop} do
    chat(user, "@bot: operable:echo test_general > chat://#general")
    Snoop.assert_no_message_received(snoop, provider: "test", target: @here)
    assert ["test_general"] = Snoop.loop_until_received(snoop, provider: "test", target: "#general")
  end

  test "redirecting to multiple places", %{user: user, snoop: snoop} do
    chat(user, "@bot: operable:echo test_all_the_things *> #foo #bar #baz")
    Snoop.assert_no_message_received(snoop, provider: "test", target: @here)
    assert ["test_all_the_things"] = Snoop.loop_until_received(snoop, provider: "test", target: "#foo")
    assert ["test_all_the_things"] = Snoop.loop_until_received(snoop, provider: "test", target: "#bar")
    assert ["test_all_the_things"] = Snoop.loop_until_received(snoop, provider: "test", target: "#baz")
  end
end
