defmodule Cog.Chat.HttpProvider do
  use GenServer
  use Cog.Chat.Provider
  alias Cog.Chat.HttpConnector
  alias Cog.Chat.Room
  alias Cog.Chat.Message
  alias Carrier.Messaging.Connection
  alias Carrier.Messaging.GenMqtt
  require Logger

  @provider_name "http"

  defstruct [:mbus, :incoming]

  def start_link(config),
    do: GenServer.start_link(__MODULE__, config, name: __MODULE__)

  ########################################################################
  # Provider Implementation

  def send_message(room, response),
    do: HttpConnector.finish_request(room, response)

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
    incoming = Keyword.fetch!(config, :incoming_topic)
    {:ok, mbus} = Connection.connect()
    {:ok, %__MODULE__{incoming: incoming, mbus: mbus}}
  end

  def handle_cast({:pipeline, %Cog.Chat.User{}=requestor, id, initial_context, pipeline}, state) do
    # In other places, we treat a room name of "direct" as a direct
    # message, so for now we'll follow that convention for the HTTP
    # provider (we should probably just rely on the `is_dm` flag
    # instead of a name, though.)
    GenMqtt.cast(state.mbus, state.incoming, "message", %Message{id: id,
                                                                 room: %Room{id: id,
                                                                             name: "direct",
                                                                             provider: @provider_name,
                                                                             is_dm: true},
                                                                 user: requestor,
                                                                 text: pipeline,
                                                                 provider: @provider_name,
                                                                 initial_context: initial_context})
    {:noreply, state}
  end
end
