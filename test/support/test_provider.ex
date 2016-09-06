defmodule Cog.Chat.Test.Provider do
  require Logger

  use GenServer
  use Cog.Chat.Provider

  @provider_name "test"

  defstruct [:conn, :incoming]

  def start_link(args),
    do: GenServer.start_link(__MODULE__, args, name: __MODULE__)

  def init(config) do
    {:ok, conn} = Carrier.Messaging.Connection.connect
    incoming = Keyword.fetch!(config, :incoming_topic)
    {:ok, %__MODULE__{conn: conn, incoming: incoming}}
  end

  ########################################################################
  # Provider API

  def lookup_user("updated-user"=handle) do
    %Cog.Chat.User{id: "U024BE7LK",
                   first_name: handle,
                   last_name: handle,
                   handle: handle,
                   provider: @provider_name,
                   email: handle}
  end
  def lookup_user(handle) do
    %Cog.Chat.User{id: handle,
                   first_name: handle,
                   last_name: handle,
                   handle: handle,
                   provider: @provider_name,
                   email: handle}
  end

  def lookup_room("user1") do
    %Cog.Chat.Room{id: "user1_dm",
                   name: "user1",
                   provider: @provider_name,
                   is_dm: true}
  end
  def lookup_room(identifier) do
    %Cog.Chat.Room{id: identifier,
                   name: identifier,
                   provider: @provider_name,
                   is_dm: false}
  end

  def list_joined_rooms() do
    {:ok, [%Room{id: "general",
                 name: "general",
                 provider: @provider_name,
                 is_dm: false}]}
  end

  def send_message(target, directives),
    do: GenServer.call(__MODULE__, {:send_message, target, directives}, :infinity)

  ########################################################################
  # Testing API

  # Tests call this
  def chat_message(%Cog.Models.User{}=user, here_id, message) when is_binary(message),
    do: GenServer.cast(__MODULE__, {:chat_message, user, here_id, message})

  ########################################################################
  # GenServer API
  def handle_cast({:chat_message, user, here_id, message}, state) do

    room = %Cog.Chat.Room{id: here_id,
                          name: here_id,
                          provider: @provider_name,
                          is_dm: false}

    Carrier.Messaging.GenMqtt.cast(state.conn,
                                   state.incoming,
                                   "message",
                                   %{id: Cog.Events.Util.unique_id,
                                     room: room,
                                     user: %Cog.Chat.User{
                                       id: user.username, # chat ids in
                                       # tests are the same as the
                                       # handle, which are the same as
                                       # the username
                                       provider: @provider_name,
                                       first_name: user.first_name,
                                       last_name: user.last_name,
                                       handle: user.username # I think
                                       # this relies on adapter module
                                       # shenanigans, though
                                     },
                                     type: "message",
                                     text: message,
                                     provider: @provider_name,
                                     bot_name: "@bot"})
    {:noreply, state}
  end
  def handle_call({:send_message, _target, _message}, _from, state) do
    # If you want the messages, snoop for them instead
    {:reply, :ok, state}
  end

end
