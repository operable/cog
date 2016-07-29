defmodule Cog.Snoop do
  @moduledoc """
  Process that collects messages sent to a specified message queue
  topic. Messages can then be retrieved and inspected for testing
  purposes.

  Example:

      # Listen to all messages that go to the Executor
      {:ok, executor_snoop} = Cog.Snoop.start_link("/bot/commands")

      # Invoke some commands, sending messages to the Executor.
      #
      # type, type, type; work, work, work

      # See what got sent to the Executor since we started snooping
      messages = Cog.Snoop.messages(executor_snoop)

      # We're done for now
      Cog.Snoop.shutdown(executor_snoop)
  """

  use GenServer
  alias Carrier.Messaging.Connection

  defstruct [:mq_conn, :topic, :messages]

  @doc """
  Start an unnamed server process that listens on `topic`.
  """
  @spec start_link(String.t) :: {:ok, pid} | {:error, term}
  def start_link(topic),
    do: GenServer.start_link(__MODULE__, topic)

  @doc """
  Retrieve all messages received by this process at the configured
  message queue topic since the process started. Messages (originally
  JSON strings) have been converted to Elixir maps.
  """
  @spec messages(pid) :: [Map.t]
  def messages(server),
    do: GenServer.call(server, :messages)

  @doc """
  Closes the message queue connection and shuts down the server.
  """
  @spec shutdown(pid) :: :ok
  def shutdown(server),
    do: GenServer.stop(server)

  ########################################################################
  # GenServer implementation details

  def init(topic) do
    {:ok, mq_conn} = Connection.connect
    Connection.subscribe(mq_conn, topic)
    {:ok, %__MODULE__{mq_conn: mq_conn, topic: topic, messages: []}}
  end

  # TODO: how best to integrate this with Conduit?
  def handle_info({:publish, topic, msg}, %__MODULE__{topic: topic}=state),
    do: {:noreply, %{state | messages: [Poison.decode!(msg)|state.messages]}}

  def handle_call(:messages, _from, state),
    do: {:reply, Enum.reverse(state.messages), state}

  def terminate(:normal, state),
    do: :emqttc.disconnect(state.mq_conn)

end
