defmodule Cog.Adapters.HipChat.XMPPHandler do
  @usage "Cog HipChat XMPP Handler"
  use Hedwig.Handler

  alias Hedwig.Stanzas.Message

  def handle_event(%Message{body: ""}, state) do
    {:ok, Map.put(state, :has_received_event, true)}
  end
  def handle_event(%Message{} = msg, state) do
    Cog.Adapters.HipChat.Connection.receive_message(msg, state)
    {:ok, Map.put(state, :has_received_event, true)}
  end
  def handle_event(_event, state) do
    {:ok, Map.put(state, :has_received_event, true)}
  end

  def handle_call(:has_received_event, state) do
    {:ok, Map.get(state, :has_received_event), state}
  end
end
