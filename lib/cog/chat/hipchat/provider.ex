defmodule Cog.Chat.HipChat.Provider do

  require Logger

  use GenServer
  use Cog.Chat.Provider

  alias Carrier.Messaging.Connection
  alias Carrier.Messaging.GenMqtt
  alias Cog.Chat.HipChat

  defstruct [:token, :jabber_id, :jabber_password, :nickname, :mbus, :xmpp, :incoming]

  def display_name, do: "Slack"

  def start_link(config) do
    case Application.ensure_all_started(:romeo) do
      {:ok, _} ->
        GenServer.start_link(__MODULE__, [config], name: __MODULE__)
      error ->
        error
    end
  end

  def init([config]) do
    token = Keyword.fetch!(config, :api_token)
    incoming = Keyword.fetch!(config, :incoming_topic)
    jabber_id = Keyword.fetch!(config, :jabber_id)
    jabber_password = Keyword.fetch!(config, :jabber_password)
    nickname = Keyword.fetch!(config, :nickname)
    use_ssl = Keyword.get(config, :ssl, true)
    case HipChat.Connector.start_link("chat.hipchat.com", jabber_id, jabber_password, nickname, use_ssl) do
      {:ok, xmpp_conn} ->
        {:ok, mbus} = Connection.connect()
        {:ok, %__MODULE__{token: token, incoming: incoming, mbus: mbus, xmpp: xmpp_conn,
                          jabber_id: jabber_id, jabber_password: jabber_password,
                          nickname: nickname}}
      error ->
        error
    end
  end

  def handle_cast({:chat_event, event}, state) do
    GenMqtt.cast(state.mbus, state.incoming, "event", event)
    {:noreply, state}
  end

end
