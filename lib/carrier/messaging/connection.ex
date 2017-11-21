defmodule Carrier.Messaging.Connection do

  require Logger

  alias Carrier.Messaging.Tracker
  alias Carrier.Messaging.Messages.MqttCall
  alias Carrier.Messaging.Messages.MqttCast
  alias Carrier.Messaging.Messages.MqttReply

  require Record
  Record.defrecord :hostent, Record.extract(:hostent, from_lib: "kernel/include/inet.hrl")

  use GenServer

  @moduledoc """
  General interface to Cog's message bus
  """

  @internal_mq_username Cog.Util.Misc.internal_mq_username
  @default_connect_timeout 5000 # 5 seconds
  @default_call_timeout 5000 # 5 seconds
  @default_log_level :error

  defstruct [:conn, :tracker, :owner]

  @typedoc "The connection to the message bus."
  @opaque connection :: pid()

  @type call_opts :: [] | [call_opt()]
  @type call_opt :: {:timeout, integer()} | {:subscriber, pid()}

  @type publish_opts :: [] | [publish_opt()]
  @type publish_opt :: {:routed_by, String.t} | {:threshold, integer()}

  @doc """
  Starts up a message bus client process.

  Additionally, logging on this connection will be done at the level
  specified in application configuration under `:carrier` -> `__MODULE__` -> `:log_level`.
  If that is not set, it defaults to the value specified in the attribute `@default_log_level`.

  By default, waits #{@default_connect_timeout} milliseconds to
  connect to the message bus. This can be overridden by passing a
  `:connect_timeout` option in `opts`.

  """
  @spec start_link(pid(), Keyword.t()) :: {:ok, connection()} | :ignore | {:error, term()}
  def start_link(owner, opts \\ []) do
    opts = opts
    |> add_connect_config
    |> add_internal_credentials

    GenServer.start_link(__MODULE__, [owner, opts])
  end

  @doc """
  Creates a GenMqtt-style reply endpoint and subscribes `subscriber` to the topic

  `subscriber` defaults to the caller's pid
  """
  @spec create_reply_endpoint(conn::connection(), subscriber::pid()) :: {:ok, String.t} | {:error, atom()}
  def create_reply_endpoint(conn, subscriber \\ self()) do
    GenServer.call(conn, {:create_reply_endpoint, subscriber}, :infinity)
  end

  @doc """
  Creates a subscription to a given topic for `subscriber`

  `subscriber` defaults to caller's pid
  """
  @spec subscribe(conn::connection(), topic::String.t, subscriber::pid()) :: {:ok, String.t} | {:error, atom()}
  def subscribe(conn, topic, subscriber \\ self()) do
    GenServer.call(conn, {:subscribe, topic, subscriber}, :infinity)
  end

  @doc """
  Removes the named subscription for `subscriber`.
  Returns true if unsubscribe was successful, false otherwise.
  """
  @spec unsubscribe(conn::connection(), topic::String.t, subscriber::pid()) :: boolean()
  def unsubscribe(conn, topic, subscriber \\ self()) do
    GenServer.call(conn, {:unsubscribe, topic, subscriber}, :infinity)
  end

  @doc """
  Publishes a message to a MQTT topic

  ## Keyword Arguments

    * `:routed_by` - the topic on which to publish `message`. Required.
  """
  @spec publish(conn::connection(), message::Map.t, opts::publish_opts()) :: :ok | {:error, atom()}
  def publish(conn, message, opts) do
    GenServer.call(conn, {:publish, message, opts}, :infinity)
  end

  @doc """
  Sends a GenMqtt call message and waits for reply
  """
  @spec call(conn::connection(), topic::String.t, endpoint::String.t, message::Map.t, opts::call_opts()) :: Map.t | {:error, atom()}
  def call(conn, topic, endpoint, message, opts \\ []) do
    subscriber = Keyword.get(opts, :subscriber, self())
    timeout = Keyword.get(opts, :timeout, @default_call_timeout)
    GenServer.call(conn, {:call, topic, endpoint, message, subscriber, timeout}, :infinity)
  end

  @doc """
  Sends a GenMqtt cast message
  """
  @spec cast(conn::connection(), topic::String.t, endpoint::String.t, message::Map.t) :: :ok | {:error, atom()}
  def cast(conn, topic, endpoint, message) do
    GenServer.call(conn, {:cast, topic, endpoint, message}, :infinity)
  end

  @doc """
  Terminates an active connection
  """
  @spec disconnect(conn::connection) :: :ok
  def disconnect(conn) do
    GenServer.call(conn, :disconnect)
  end


  def init([owner, opts]) do
    try do
      Process.link(owner)
      Logger.debug("MQTT connection #{inspect self()} started")
      connect_timeout = Keyword.get(opts, :connect_timeout, @default_connect_timeout)
      {:ok, conn} = :emqttc.start_link(opts)

      # `emqttc:start_link/1` returns a message bus client process, but it
      # hasn't yet established a network connection to the message bus. By
      # ensuring that we only return after the process is actually connected,
      # we can simplify startup of processes that require a message bus
      # connection.
      #
      # It also means that those clients don't have to know details about
      # emqttc (like the structure of the "connected" message), so fewer
      # implementation details about our choice of message bus don't leak out.
      #
      # If we don't connect after a specified timeout, we just fail.
      receive do
        {:mqttc, ^conn, :connected} ->
          {:ok, %__MODULE__{conn: conn,
                            owner: owner,
                            tracker: %Tracker{}}}
      after connect_timeout ->
          Logger.info("Connection not established")
          {:stop, :econnrefused}
      end
    rescue
      # Detect when the connection owner has exited before the connection
      # could link to it. Prevents long stack traces from polluting
      # log output.
      e in ErlangError ->
        Logger.error("Linking to owner process failed: #{Exception.message(e)}")
      {:stop, :failed_owner_link}
    end

  end

  def handle_call({:create_reply_endpoint, subscriber}, _from, %__MODULE__{tracker: tracker}=state) do
    {tracker, topic} = Tracker.add_reply_endpoint(tracker, subscriber)
    unless Enum.member?(:emqttc.topics(state.conn), {topic, :qos1}) do
      :emqttc.sync_subscribe(state.conn, topic, :qos1)
    end
    {:reply, {:ok, topic}, %{state | tracker: tracker}}
  end
  def handle_call({:subscribe, topic, subscriber}, _from, %__MODULE__{tracker: tracker}=state) do
    tracker = Tracker.add_subscription(tracker, topic, subscriber)
    unless Enum.member?(:emqttc.topics(state.conn), {topic, :qos1}) do
      :emqttc.sync_subscribe(state.conn, topic, :qos1)
    end
    {:reply, {:ok, topic}, %{state | tracker: tracker}}
  end
  def handle_call({:unsubscribe, topic, subscriber}, _from, %__MODULE__{tracker: tracker}=state) do
    {tracker, deleted} = Tracker.del_subscription(tracker, topic, subscriber)
    state = if deleted do
      drop_unused_topics(%{state | tracker: tracker})
    else
      state
    end
    {:reply, deleted, state}
  end
  def handle_call({:publish, message, opts}, _from, state) do
    case Keyword.get(opts, :routed_by) do
      nil ->
        {:reply, {:error, :no_topic}, state}
      topic ->
        case message.__struct__.encode(message) do
          {:ok, encoded} ->
            case :snappy.compress(encoded) do
              {:ok, compressed} ->
                case :emqttc.sync_publish(state.conn, topic, compressed, :qos1) do
                  {:ok, _} ->
                    {:reply, :ok, state}
                  error ->
                    {:reply, error, state}
                end
              error ->
                {:reply, error, state}
            end
          error ->
            {:reply, error, state}
        end
    end
  end
  def handle_call({:call, topic, endpoint, payload, subscriber, timeout}, from, state) do
    case Tracker.get_reply_endpoint(state.tracker, subscriber) do
      nil ->
        {:reply, {:error, :no_reply_endpoint}, state}
      reply_endpoint ->
        flush_pending(reply_endpoint)
        message = %MqttCall{sender: reply_endpoint, endpoint: endpoint, payload: payload}
        case handle_call({:publish, message, routed_by: topic}, from, state) do
          {:reply, :ok, state} ->
            # Wait for response
            receive do
              {:publish, ^reply_endpoint, compressed} ->
                case :snappy.decompress(compressed) do
                  {:ok, payload} ->
                    {:reply, MqttReply.decode(payload), state}
                  error ->
                    {:reply, error, state}
                end
            after timeout ->
              {:reply, {:error, :call_timeout}, state}
            end
          error ->
            error
        end
    end
  end
  def handle_call({:cast, topic, endpoint, payload}, from, state) do
    message = %MqttCast{endpoint: endpoint, payload: payload}
    handle_call({:publish, message, routed_by: topic}, from, state)
  end
  def handle_call(:disconnect, _from, state) do
    unless state.owner == nil do
      Process.unlink(state.owner)
    end
    :emqttc.disconnect(state.conn)
    {:stop, :shutdown, :ok, state}
  end

  def handle_info({:DOWN, _mref, :process, subscriber, _}, %__MODULE__{tracker: tracker}=state) do
    tracker = Tracker.del_subscriber(tracker, subscriber)
    {:noreply, drop_unused_topics(%{state | tracker: tracker})}
  end
  def handle_info({:publish, topic, compressed}, state) do
    case Tracker.find_subscribers(state.tracker, topic) do
      [] ->
        {:noreply, state}
      subscribed ->
        case :snappy.decompress(compressed) do
          {:ok, payload} ->
            message = {:publish, topic, payload}
            Enum.each(subscribed, &(Process.send(&1, message, [])))
            {:noreply, state}
          error ->
            Logger.error("Decompressing MQTT payload failed: #{inspect error}")
            {:noreply, state}
        end
    end
  end
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  def terminate(reason, _state) do
    Logger.debug("MQTT connection #{inspect self()} closed: #{inspect reason}")
  end

  ########################################################################

  defp add_internal_credentials(opts) do
    opts
    |> Keyword.put(:username, "guest")
    |> Keyword.put(:password, "guest")
    # opts
    # |> Keyword.put(:username, @internal_mq_username)
    # |> Keyword.put(:password, Application.fetch_env!(:cog, :message_queue_password))
  end

  defp add_connect_config(opts) do
    connect_opts = Application.get_env(:cog, __MODULE__)
    host = Keyword.fetch!(connect_opts, :host)
    port = Keyword.fetch!(connect_opts, :port)
    log_level = Keyword.get(connect_opts, :log_level, @default_log_level)
    host = case is_binary(host) do
             true ->
               {:ok, hostent} = :inet.gethostbyname(String.to_char_list(host))
               List.first(hostent(hostent, :h_addr_list))
             false ->
               host
           end
    updated = [{:host, host}, {:port, port}, {:logger, {:lager, log_level}} | opts]
    configure_ssl(updated, connect_opts)
  end

  # Enable SSL connections when SSL config is provided
  defp configure_ssl(opts, connect_opts) do
    case Keyword.get(connect_opts, :ssl, false) do
      false ->
        opts
      true ->
        build_ssl_config(:verify, opts, connect_opts)
      :verify ->
        build_ssl_config(:verify, opts, connect_opts)
      :unverified ->
        build_ssl_config(:unverified, opts, connect_opts)
      :no_verify ->
        build_ssl_config(:unverified, opts, connect_opts)
    end
  end

  defp build_ssl_config(kind, opts, connect_opts) do
    cacertfile = Keyword.get(connect_opts, :ssl_cert, "")
    if cacertfile == "" do
      Logger.error(":cog/Carrier.Messaging.Connection/:ssl_cert config entry is missing. SSL client connections are disabled.")
      opts
    else
      ssl_opts = [crl_check: true, cacertfile: String.to_charlist(cacertfile)]
      ssl_opts = if kind == :verify do
        [{:verify, :verify_peer}|ssl_opts]
      else
        [{:verify, :verify_none}|ssl_opts]
      end
      [{:ssl, ssl_opts}|opts]
    end
  end

  # Receive and drop and pending sent messages
  # on a topic
  defp flush_pending(topic) do
    receive do
      {:publish, ^topic, _} ->
        flush_pending(topic)
    after 0 ->
        :ok
    end
  end

  defp drop_unused_topics(%__MODULE__{tracker: tracker, conn: conn}=state) do
    {tracker, unused_topics} = Tracker.get_and_reset_unused_topics(tracker)
    Enum.each(unused_topics, &(:emqttc.unsubscribe(conn, &1)))
    %{state | tracker: tracker}
  end

end
