defmodule Cog.Chat.SlackProvider do

  require Logger

  use GenServer
  use Cog.Chat.Provider

  alias Carrier.Messaging.Connection
  alias Carrier.Messaging.GenMqtt
  alias Cog.Chat.SlackConnector

  defstruct [:token, :incoming, :connector, :mbus]

  def start_link(config) do
    GenServer.start_link(__MODULE__, [config], name: __MODULE__)
  end

  def lookup_user(handle) do
    GenServer.call(__MODULE__, {:lookup_user, handle}, :infinity)
  end

  def list_joined_rooms() do
    GenServer.call(__MODULE__, :list_joined_rooms, :infinity)
  end

  def join(room) do
    GenServer.call(__MODULE__, {:join, room}, :infinity)
  end

  def leave(room) do
    GenServer.call(__MODULE__, {:leave, room}, :infinity)
  end

  def send_message(target, message) do
    GenServer.call(__MODULE__, {:send_message, target, message}, :infinity)
  end

  def init([config]) do
    token = Keyword.fetch!(config, :api_token)
    incoming = Keyword.fetch!(config, :incoming_topic)
    {:ok, mbus} = Connection.connect()
    {:ok, pid} = SlackConnector.start_link(token)
    {:ok, %__MODULE__{token: token, incoming: incoming, connector: pid, mbus: mbus}}
  end

  def handle_call({:lookup_user, handle}, _from, %__MODULE__{connector: connector, token: token}=state) do
    {:reply, SlackConnector.call(connector, token, :lookup_user, %{handle: handle}), state}
  end
  def handle_call(:list_joined_rooms, _from, %__MODULE__{connector: connector, token: token}=state) do
    {:reply, SlackConnector.call(connector, token, :list_joined_rooms), state}
  end
  def handle_call({:join, room}, _from, %__MODULE__{connector: connector, token: token}=state) do
    case SlackConnector.call(connector, token, :join, %{room: room}) do
      %{"ok" => true} ->
        {:reply, :ok, state}
      reply ->
        {:reply, {:error, reply["error"]}, state}
    end
  end
  def handle_call({:leave, room}, _from, %__MODULE__{connector: connector, token: token}=state) do
    case SlackConnector.call(connector, token, :leave, %{room: room}) do
      %{"ok" => true} ->
        {:reply, :ok, state}
      reply ->
        {reply, {:error, reply["error"]}, state}
    end
  end
  def handle_call({:send_message, target, message}, _from, %__MODULE__{connector: connector, token: token}=state) do
    {:reply, SlackConnector.call(connector, token, :send_message, %{target: target, message: message}), state}
  end

  def handle_cast({:chat_event, event}, %__MODULE__{mbus: conn, incoming: incoming}=state) do
    GenMqtt.cast(conn, incoming, "event", event)
    {:noreply, state}
  end
  def handle_cast({:chat_message, msg}, %__MODULE__{mbus: conn, incoming: incoming}=state) do
    GenMqtt.cast(conn, incoming, "message", msg)
    {:noreply, state}
  end
end
