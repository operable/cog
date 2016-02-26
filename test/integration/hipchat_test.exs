defmodule Integration.HipChatTest do
  use Cog.AdapterCase, adapter: "hipchat"
  alias Cog.Time

  @moduletag :hipchat
  @timeout 10000
  @interval 1000

  def wait_for_xmpp_connection do
    until = Time.now + (@timeout / 1000)
    wait_for_xmpp_connection(until)
  end
  def wait_for_xmpp_connection(until) do
    # Catch if we try to talk to the HipChat.Connection before it has started
    has_received_event = try do
      event_manager = Cog.Adapters.HipChat.Connection.event_manager
      GenEvent.call(event_manager, Cog.Adapters.HipChat.XMPPHandler, :has_received_event)
    catch
      :exit, _ -> false
    end

    unless has_received_event do
      :timer.sleep(@interval) # 1 second

      if Time.now > until do
        raise "Timed out waiting for xmpp connection"
      else
        wait_for_xmpp_connection(until)
      end
    end
  end

  setup do
    wait_for_xmpp_connection

    user = user("ciuser")
    |> with_chat_handle_for("hipchat")

    {:ok, %{user: user}}
  end

  test "running the st-echo command", %{user: user} do
    user |> with_permission("operable:st-echo")

    message = send_message user, "@deckard operable:st-echo test"
    assert_response "test", after: message
  end

  test "running the st-echo command without permission", %{user: user} do
    message = send_message user, "@deckard operable:st-echo test"
    assert_response "@ciuser Sorry, you aren't allowed to execute 'operable:st-echo test' :(\n You will need the 'operable:st-echo' permission to run this command.", after: message
  end

  test "running commands in a pipeline", %{user: user} do
    user
    |> with_permission("operable:echo")
    |> with_permission("operable:thorn")

    message = send_message user, ~s(@deckard operable:echo "this is a test" | operable:thorn $body)
    assert_response "þis is a test", after: message
  end

  test "running commands in a pipeline without permission", %{user: user} do
    user |> with_permission("operable:st-echo")

    message = send_message user, ~s(@deckard operable:st-echo "this is a test" | operable:st-thorn $body)
    assert_response "@ciuser Sorry, you aren't allowed to execute 'operable:st-thorn $body' :(\n You will need the 'operable:st-thorn' permission to run this command.", after: message
  end
end
