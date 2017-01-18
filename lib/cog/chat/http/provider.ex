defmodule Cog.Chat.Http.Provider do
  use GenServer
  use Cog.Chat.Provider

  alias Carrier.Messaging.{Connection, ConnectionSup}
  alias Cog.Chat.Http.Connector
  alias Cog.Chat.Message
  alias Cog.Chat.Room

  require Logger

  @provider_name "http"

  defstruct [:mbus, :incoming_message_topic]

  def start_link(config),
    do: GenServer.start_link(__MODULE__, config, name: __MODULE__)

  ########################################################################
  # Provider Implementation

  def send_message(room, response),
    do: Connector.finish_request(room, response)

  def lookup_room(_room),
    do: {:error, :not_found}

  # TODO: Do we need this implementation?
  def mention_name(name),
    do: name

  def display_name,
    do: "HTTP"

  ########################################################################
  # GenServer Implementation

  def init(config) do
    incoming_message = Keyword.fetch!(config, :incoming_message_topic)
    {:ok, mbus} = ConnectionSup.connect()
    {:ok, %__MODULE__{incoming_message_topic: incoming_message, mbus: mbus}}
  end

  def handle_cast({:pipeline, %Cog.Chat.User{}=requestor, id, initial_context, pipeline}, state) do
    # In other places, we treat a room name of "direct" as a direct
    # message, so for now we'll follow that convention for the HTTP
    # provider (we should probably just rely on the `is_dm` flag
    # instead of a name, though.)
    Connection.publish(state.mbus, %Message{id: id,
                                            room: %Room{id: id,
                                                        name: "direct",
                                                        provider: @provider_name,
                                                        is_dm: true},
                                            user: requestor,
                                            text: pipeline,
                                            provider: @provider_name,
                                            initial_context: initial_context}, routed_by: state.incoming_message_topic)
    {:noreply, state}
  end
end
