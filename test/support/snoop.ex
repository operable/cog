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
  require Logger

  defstruct [:mq_conn, :topic, messages: []]

  # Wait a total of @tries x @wait ms to receive a single response
  # from the test adapter
  @tries 100
  @wait 50 # ms

  @doc """
  Start an unnamed server process that listens on `topic`.
  """
  def start_link(topic),
    do: GenServer.start_link(__MODULE__, topic)

  @doc """
  Convenience function that abstracts the message queue topic for
  messages going to the adapter
  """
  def adapter_traffic,
    do: start_link("bot/chat/adapter")

  @doc """
  Convenience function for listening to requests sent to the executor
  """
  def incoming_executor_traffic,
    do: start_link("/bot/commands")

  @doc """
  Helper function for looping until a Snoop receives a message
  targeted to a chat provider.
  """
  def loop_until_received(snoop, opts) do
    provider = Keyword.get(opts, :provider, "test")
    target   = Keyword.get(opts, :target)
    loop_until_received(snoop, provider, target, @tries)
  end

  @doc """
  Helper assertion for the case where you want to assert that a chat
  provider doesn't receive a message during a test
  """
  def assert_no_message_received(snoop, opts) do
    import ExUnit.Assertions
    results = try do
                loop_until_received(snoop, opts)
              rescue
                e in RuntimeError ->
                  if e.message == "Didn't get a message!" do
                    []
                  else
                    raise e
                  end
              end

    if results == [] do
      :ok
    else
      flunk """
      Expected no messages, but received some!

      #{inspect(results)}
      """
    end
  end

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
    {:ok, %__MODULE__{mq_conn: mq_conn,
                      topic: topic,
                      messages: []}}
  end

  # TODO: how best to integrate this with Conduit?
  def handle_info({:publish, topic, msg}, %__MODULE__{topic: topic}=state),
    do: {:noreply, %{state | messages: [Poison.decode!(msg) | state.messages]}}
  def handle_info(message, state) do
    Logger.warn("Received unexpected message: #{inspect message}")
    {:noreply, state}
  end

  def handle_call(:messages, _from, state),
    do: {:reply, Enum.reverse(state.messages), state}

  def terminate(:normal, state),
    do: Connection.disconnect(state.mq_conn)

  ########################################################################
  # Directive Processing

  defp render(directives) when is_list(directives) do
    directives
    |> Enum.map(&render_directive/1)
    |> Enum.join
  end

  # The only fixed_width we should see in the tests is from the raw
  # tag, so text will just be JSON
  defp render_directive(%{"name" => "fixed_width", "text" => text}),
    do: text
  # We can also get plain text (e.g., from `echo` output)
  defp render_directive(%{"name" => "text", "text" => text}),
    do: text
  defp render_directive(%{"name" => "newline"}),
    do: "\n"

  ########################################################################
  # Message processing functions

  defp loop_until_received(_, _, _, 0),
    do: raise "Didn't get a message!"
  defp loop_until_received(snoop, provider, target, count) do
    :timer.sleep(@wait)
    responses = snoop
    |> messages()
    |> to_endpoint("send")
    |> to_provider(provider)

    responses = if target do
      targeted_to(responses, target)
    else
      responses
    end

    case bare_messages(responses) do
      [] ->
        loop_until_received(snoop, provider, target, count - 1)
      responses ->
        responses
    end
  end

  defp to_endpoint(messages, endpoint),
    do: Enum.filter(messages, fn(m) -> Map.get(m, "endpoint") == endpoint end)

  defp to_provider(messages, provider),
    do: Enum.filter(messages, fn(m) -> get_in(m, ["payload", "provider"]) == provider end)

  defp targeted_to(messages, target),
    do: Enum.filter(messages, fn(m) -> get_in(m, ["payload", "target"]) == target end)

  defp bare_messages(messages) do
    Enum.map(messages, fn(m) ->
      msg = get_in(m, ["payload", "message"])

      if get_in(m, ["payload", "provider"]) == "http" do
        # Just return the raw message for HTTP adapter
        msg
      else
        msg = render(msg)
        # TODO: We should probably stop decoding to keys; a bunch of
        # tests are coded for atoms, though. We can get this on a
        # separate refactoring pass if we want
        case Poison.decode(msg, keys: :atoms) do
          {:ok, decoded} ->
            decoded
          {:error, _} ->
            msg
        end
      end
    end)
  end


end
