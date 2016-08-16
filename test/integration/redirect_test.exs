defmodule Integration.RedirectTest do
  use Cog.AdapterCase, adapter: "test"
  alias Cog.Snoop # TODO: fold this into AdapterCase?
  require Logger

  setup do
    user = user("vanstee", first_name: "Patrick", last_name: "Van Stee")
    |> with_chat_handle_for("test")

    {:ok, snoop} = Snoop.adapter_traffic
    {:ok, %{user: user,
            snoop: snoop}}
  end

  @here "I_AM_HERE"

  # TODO: find a way to wait until we've got the expected number of messages?
  defp wait,
    do: :timer.sleep(1500)

  defp messages_targeted_to(snoop, target) do
    messages = snoop
    |> Snoop.messages
    |> Snoop.to_endpoint("send")
    |> Snoop.to_provider("test")
    |> Snoop.targeted_to(target)
    |> Snoop.bare_messages

    case messages do
      [message] -> message
      _ -> messages
    end
  end

  defp chat(user, text) do
    send_message(user, @here, text)
    wait
  end

  test "redirecting to 'here'", %{user: user, snoop: snoop} do
    chat(user, "@bot: operable:echo test_here > here")
    assert %{"body" => ["test_here"]} = snoop |> messages_targeted_to(@here)
  end

  test "redirection to '#general'", %{user: user, snoop: snoop} do
    chat(user, "@bot: operable:echo test_general > #general")
    assert [] = snoop |> messages_targeted_to(@here)
    assert %{"body" => ["test_general"]} = snoop |> messages_targeted_to("#general")
  end

  test "redirection to 'general'", %{user: user, snoop: snoop} do
    chat(user, "@bot: operable:echo test_general > general")
    assert [] = snoop |> messages_targeted_to(@here)
    assert %{"body" => ["test_general"]} = snoop |> messages_targeted_to("general")
  end

  test "redirection to 'me'", %{user: user, snoop: snoop} do
    chat(user, "@bot: operable:t-echo test_me > me")
    assert [] = snoop |> messages_targeted_to(@here)
    assert %{"body" => ["test_me"]} = snoop |> messages_targeted_to("vanstee")
  end

  test "redirection to 'vanstee'", %{user: user, snoop: snoop} do
    chat(user, "@bot: operable:echo test_vanstee > vanstee")
    assert [] = snoop |> messages_targeted_to(@here)
    assert %{"body" => ["test_vanstee"]} = snoop |> messages_targeted_to("vanstee")
  end

  test "redirection to '@vanstee'", %{user: user, snoop: snoop} do
    chat(user, "@bot: operable:echo test_vanstee > @vanstee")
    assert [] = snoop |> messages_targeted_to(@here)
    assert %{"body" => ["test_vanstee"]} = snoop |> messages_targeted_to("@vanstee")
  end

  test "redirection to 'chat://@vanstee'", %{user: user, snoop: snoop} do
    chat(user, "@bot: operable:echo test_vanstee > chat://@vanstee")
    assert [] = snoop |> messages_targeted_to(@here)
    assert %{"body" => ["test_vanstee"]} = snoop |> messages_targeted_to("@vanstee")
  end

  test "redirection to 'chat://#general'", %{user: user, snoop: snoop} do
    chat(user, "@bot: operable:echo test_general > chat://#general")
    assert [] = snoop |> messages_targeted_to(@here)
    assert %{"body" => ["test_general"]} = snoop |> messages_targeted_to("#general")
  end

  test "redirecting to multiple places", %{user: user, snoop: snoop} do
    chat(user, "@bot: operable:echo test_all_the_things *> #foo #bar #baz")
    assert [] = snoop |> messages_targeted_to(@here)
    assert %{"body" => ["test_all_the_things"]} = snoop |> messages_targeted_to("#foo")
    assert %{"body" => ["test_all_the_things"]} = snoop |> messages_targeted_to("#bar")
    assert %{"body" => ["test_all_the_things"]} = snoop |> messages_targeted_to("#baz")
  end
end
