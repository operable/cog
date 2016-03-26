defmodule Cog.Adapter do
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts], location: :keep do
      use GenServer
      require Logger

      @behaviour Cog.Adapter

      def receive_message(sender, room, message) do
        GenServer.call(__MODULE__, {:receive_message, sender, room, message})
      end

      def start_link() do
        GenServer.start_link(__MODULE__, [], name: __MODULE__)
      end

      def init([]) do
        {:ok, conn} = Carrier.Messaging.Connection.connect()
        Carrier.Messaging.Connection.subscribe(conn, topic())

        {:ok, %{conn: conn}}
      end

      def handle_call({:receive_message, sender, room, message}, _from, state) do
        message = payload(sender, room, message)
        Carrier.Messaging.Connection.publish(state.conn, message, routed_by: "/bot/commands")
        {:reply, :ok, state}
      end

      def handle_info({:publish, topic, message}, state) do
        if topic == reply_topic() do
          payload = Poison.decode!(message)
          send_message(payload["room"], payload["response"])
        end

        {:noreply, state}
      end

      def handle_info(_, state) do
        {:noreply, state}
      end

      defp payload(sender, room, text) do
        %{id: UUID.uuid4(:hex),
          sender: sender,
          room: room,
          text: text,
          adapter: name(),
          module: __MODULE__,
          reply: reply_topic()}
      end

      defp topic() do
        "/bot/adapters/" <> name() <> "/+"
      end

      def reply_topic do
        "/bot/adapters/" <> name() <> "/send_message"
      end
    end
  end

  @type lookup_result() :: {:ok, String.t} | nil | {:error, any}
  @type lookup_opts() :: [id: String.t] | [name: String.t]

  @callback receive_message(sender :: Map.t, room :: Map.t, message :: String.t) :: :ok | :error

  @callback send_message(room :: Map.t, message :: String.t) :: :ok | :error

  @callback lookup_room(lookup_opts()) :: lookup_result()

  @callback lookup_direct_room(lookup_opts()) :: lookup_result()

  @callback room_writeable?(lookup_opts()) :: boolean() | {:error, any}

  @callback lookup_user(lookup_opts()) :: lookup_result()

  @callback mention_name(String.t) :: String.t

  @callback name() :: String.t

  @callback display_name() :: String.t

  @callback reply_topic() :: String.t
end
