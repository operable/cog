defmodule Cog.Chat.Slack.Provider do

  require Logger

  use GenServer
  use Cog.Chat.Provider

  alias Carrier.Messaging.Connection
  alias Carrier.Messaging.GenMqtt
  alias Cog.Chat.Slack.Connector

  defstruct [:token, :incoming, :connector, :mbus]

  def display_name, do: "Slack"

  def start_link(config) do
    case Application.ensure_all_started(:slack) do
      {:ok, _} ->
        GenServer.start_link(__MODULE__, [config], name: __MODULE__)
      error ->
        error
    end
  end

  def mention_name(handle) do
    # Lookup the user and return the id properly formatted instead of just the
    # handle. If we just return the handle slack doesn't always recognize the
    # handle and alert the user. For example, when you return the mention name
    # followed by a colon.
    case lookup_user(handle) do
      %Cog.Chat.User{id: id} -> "<@#{id}>"
      _ -> super(handle)
    end
  end

  def lookup_room({:id, id}),
    do: GenServer.call(__MODULE__, {:lookup_room, {:id, id}}, :infinity)
  def lookup_room({:name, name}),
    do: GenServer.call(__MODULE__, {:lookup_room, {:name, name}}, :infinity)

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
    if String.starts_with?(token, "xoxb") == false do
      Logger.error("""
      Incorrect Slack API token type detected.
      Cog requires a Slack API bot token which begin with 'xoxb-'.
      Current token is '#{token}'.
      """)
      {:stop, :bad_slack_token}
    else
      incoming = Keyword.fetch!(config, :incoming_topic)

      {:ok, mbus} = Connection.connect()
      {:ok, pid} = Connector.start_link(token)
      {:ok, %__MODULE__{token: token, incoming: incoming, connector: pid, mbus: mbus}}
    end
  end

  def handle_call({:lookup_room, {:id, id}}, _from, %__MODULE__{connector: connector, token: token}=state) do
    {:reply, Connector.call(connector, token, :lookup_room, %{id: id}), state}
  end
  def handle_call({:lookup_room, {:name, name}}, _from, %__MODULE__{connector: connector, token: token}=state) do
    {:reply, Connector.call(connector, token, :lookup_room, %{name: name}), state}
  end

  def handle_call({:lookup_user, handle}, _from, %__MODULE__{connector: connector, token: token}=state) do
    {:reply, Connector.call(connector, token, :lookup_user, %{handle: handle}), state}
  end
  def handle_call(:list_joined_rooms, _from, %__MODULE__{connector: connector, token: token}=state) do
    {:reply, Connector.call(connector, token, :list_joined_rooms), state}
  end
  def handle_call({:join, room}, _from, %__MODULE__{connector: connector, token: token}=state) do
    case Connector.call(connector, token, :join, %{room: room}) do
      %{"ok" => true} ->
        {:reply, :ok, state}
      reply ->
        {:reply, {:error, reply["error"]}, state}
    end
  end
  def handle_call({:leave, room}, _from, %__MODULE__{connector: connector, token: token}=state) do
    case Connector.call(connector, token, :leave, %{room: room}) do
      %{"ok" => true} ->
        {:reply, :ok, state}
      reply ->
        {reply, {:error, reply["error"]}, state}
    end
  end
  # Old template processing
  def handle_call({:send_message, target, message}, _from, %__MODULE__{connector: connector, token: token}=state) when is_binary(message) do
    result = Connector.call(connector, token, :send_message, %{target: target, message: message})
    case result["ok"] do
      true ->
        {:reply, :ok, state}
      false ->
        {:reply, {:error, result["error"]}, state}
    end
  end
  # New template processing
  def handle_call({:send_message, target, message}, _from, %__MODULE__{connector: connector, token: token}=state) do
    {text, attachments} = Cog.Chat.Slack.TemplateProcessor.render(message)
    result = Connector.call(connector, token, :send_message, %{target: target, message: text, attachments: attachments})
    case result["ok"] do
      true ->
        {:reply, :ok, state}
      false ->
        {:reply, {:error, result["error"]}, state}
    end
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
