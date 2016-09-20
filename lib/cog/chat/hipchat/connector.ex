defmodule Cog.Chat.HipChat.RosterEntry do

  defstruct [:jid, :mention, :name, :email]

  def from_xmpp(item) do
    jid = item.jid.user
    name = item.name
    {:xmlel, "item", attrs, _} = item.xml
    mention_name = :proplists.get_value("mention_name", attrs, nil)
    email = :proplists.get_value("email", attrs, nil)
    %__MODULE__{jid: jid, mention: mention_name, name: name, email: email}
  end

end

defmodule Cog.Chat.HipChat.Connector do

  require Logger

  use GenServer

  alias Cog.Chat.HipChat.Provider
  alias Cog.Chat.HipChat.RosterEntry
  alias Cog.Chat.HipChat.Util
  alias Romeo.Connection
  alias Romeo.Roster
  alias Romeo.Stanza


  @heartbeat_interval 30000

  defstruct [:provider, :xmpp_conn, :hipchat_org, :me, :mention_name, :roster, :fatal_error]

  def start_link(host, user, password, nickname, use_ssl) do
    opts = [jid: user,
            password: password,
            host: host,
            mention_name: nickname,
            require_tls: use_ssl]
    GenServer.start_link(__MODULE__, [opts, self()], name: __MODULE__)
  end

  def init([opts, provider]) do
    [user_name|_] = String.split(Keyword.fetch!(opts, :jid), "@", parts: 2)
    [hipchat_org|_] = String.split(user_name, "_", parts: 2)
    case Connection.start_link(opts) do
      {:ok, conn} ->
        case Connection.send(conn, Stanza.presence) do
          :ok ->
            Logger.info("Successfully connected to HipChat org #{hipchat_org}")
            {:ok, %__MODULE__{provider: provider, xmpp_conn: conn, hipchat_org: hipchat_org,
                              me: Keyword.fetch!(opts, :jid), mention_name: Keyword.fetch!(opts, :mention_name)}}
          error ->
            error
        end
      error ->
        error
    end
  end

  # Should only happen when we connect
  def handle_info(:connection_ready, state) do
    roster = Enum.reduce(Roster.items(state.xmpp_conn), %{},
      fn(item, roster) ->
        entry = RosterEntry.from_xmpp(item)
        roster = if entry.mention != nil do
          Map.put(roster, entry.mention, entry)
        else
          roster
        end
        Map.put(roster, entry.jid, entry)
      end)
    :timer.send_interval(@heartbeat_interval, :heartbeat)
    {:noreply, %{state | roster: roster}}
  end
  # Send heartbeat
  def handle_info(:heartbeat, state) do
    case Connection.send(state.xmpp_conn, Stanza.chat(state.me, "//hb\\")) do
      :ok ->
        :ok
      error ->
        Logger.error("Failed to send heartbeat message to HipChat: #{inspect error}")
    end
    {:noreply, state}
  end
  def handle_info({:stanza, %Stanza.Presence{}=presence}, state) do
    handle_presence(state, presence)
    {:noreply, state}
  end
  def handle_info({:stanza, %Stanza.Message{}=message}, state) do
    case Util.check_invite(message) do
      false ->
        {:noreply, state}
      {true, room_name} ->
        Logger.info("Received an invite to MUC room '#{room_name}'")
        muc_name = "#{state.hipchat_org}_#{room_name}@conf.hipchat.com"
        case Connection.send(state.xmpp_conn, Stanza.join(muc_name, state.mention_name)) do
          :ok ->
            Logger.info("Successfully joined MUC room '#{room_name}'")
          error ->
            Logger.error("Failed to join MUC room '#{room_name}': #{inspect error}")
        end
        {:noreply, state}
    end
  end
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # Error states
  def pending_error(:timeout, state) do
    Logger.error("Error handling HipChat message: #{inspect state.fatal_error}")
    {:stop, :shutdown, state}
  end

  def terminate(_, _, _), do: :ok

  defp handle_presence(state, presence) do
    case Map.get(state.roster, presence.from.user) do
      nil ->
        :ok
      user ->
        event = build_event(user, presence)
        GenServer.cast(Provider, event)
    end
  end

  defp build_event(user, %Stanza.Presence{}=presence) do
    {:chat_event, %{"presence" => presence_type(presence.show), "provider" => "hipchat", "type" => "presence_change",
                    "user" => %{"email" => user.email, "name" => user.name, "id" => user.jid, "handle" => user.mention,
                                "provider" => "hipchat"}}}
  end

  defp presence_type("xa"), do: "inactive"
  defp presence_type("away"), do: "inactive"
  defp presence_type("chat"), do: "active"
  defp presence_type(""), do: "active"


end
