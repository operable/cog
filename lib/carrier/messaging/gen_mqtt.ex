defmodule Carrier.Messaging.GenMqtt do

  @infinity_timeout 3600000 # one hour in millis

  use Adz
  use GenServer
  alias Carrier.Messaging.Connection
  alias Carrier.Messaging.Messages.MqttCall
  alias Carrier.Messaging.Messages.MqttCast
  alias Carrier.Messaging.Messages.MqttReply

  @type call_timeout :: integer | :infinity

  @callback init(conn :: Connection.connection, args :: term) ::
    {:ok, state} |
    {:stop, reason :: any} when state: any

  @callback handle_message(conn :: Connection.connection, topic :: String.t, body :: binary, state :: any) ::
    {:reply, String.t, binary, state} |
    {:noreply, state} |
    {:stop, reason :: any} when state: any

  @callback handle_call(conn :: Connection.connection, topic :: String.t, sender :: String.t, endpoint :: String.t, body :: map, state :: any) ::
    {:reply, {:ok, map} | {:error, map}, state} |
    {:noreply, state} |
    {:stop, reason :: any} when state: any

  @callback handle_cast(conn :: Connection.connection, topic :: String.t, endpoint :: String.t, body :: map, state :: any) ::
    {:noreply, state} |
    {:stop, reason :: any} when state: any

  @callback handle_admin(message :: any, state :: any) ::
    {:noreply, state} |
    {:stop, reason :: any} when state: any

  defstruct [:cb, :cb_state, :conn]

  defmacro __using__(_) do
    quote do
      @behaviour unquote(__MODULE__)

      require Logger

      alias unquote(__MODULE__)
      alias Carrier.Messaging.Connection

      def init(_conn, args), do: {:ok, :undefined}

      def handle_message(_conn, topic, _body, state) do
        Logger.info("Ignoring message received on topic '#{topic}'.")
        {:noreply, state}
      end

      def handle_call(_conn, _topic, _sender, _endpoint, _body, state) do
        {:reply, {:error, "not implemented"}, state}
      end

      def handle_cast(_conn, _topic, _endpoint, _body, state) do
        {:noreply, state}
      end

      def handle_admin(_message, state) do
        {:noreply, state}
      end

      defoverridable [init: 2, handle_message: 4, handle_call: 6, handle_cast: 5, handle_admin: 2]
    end
  end

  @spec start_link(cb :: module, args :: term, opts :: Keyword.t) :: {:ok, pid} | {:error, reason :: any}
  def start_link(cb, args, opts \\ []) do
    GenServer.start_link(__MODULE__, [%{cb: cb, args: args}], opts)
  end

  def call(topic, endpoint, call_args, timeout \\ 5000), do: call(nil, topic, endpoint, call_args, timeout)

  @spec call(conn :: Connection.connection, topic :: String.t, endpoint :: String.t, call_args :: map, timeout :: call_timeout) ::
    {:ok, result :: any} |
    {:error, reason :: any}
  def call(nil, topic, endpoint, call_args, timeout) do
    {:ok, conn} = Connection.connect()
    result = call(conn, topic, endpoint, call_args, timeout)
    Connection.disconnect(conn)
    result
  end
  def call(conn, topic, endpoint, call_args, timeout) do
    timeout = case timeout do
                :infinity ->
                  @infinity_timeout
                n ->
                  n
              end
    case Connection.call(conn, topic, endpoint, call_args, timeout) do
      {:error, :call_timeout} ->
        {:error, :timeout}
      %MqttReply{flag: "error", result: [result]} ->
        {:error, result}
      %MqttReply{flag: "ok", result: [result]} ->
        {:ok, result}
    end
  end

  def cast(topic, endpoint, cast_args), do: cast(nil, topic, endpoint, cast_args)

  @spec cast(conn :: Connection.connection, topic :: String.t, endpoint :: String.t, cast_args :: map) ::
    :ok |
    {:error, reason :: any}
  def cast(nil, topic, endpoint, cast_args) do
    {:ok, conn} = Connection.connect()
    result = cast(conn, topic, endpoint, cast_args)
    Connection.disconnect(conn)
    result
  end
  def cast(conn, topic, endpoint, cast_args) do
    Connection.cast(conn, topic, endpoint, cast_args)
  end

  @spec admin(server :: pid | atom, message :: any) :: :ok
  def admin(server, message) do
    GenServer.cast(server, {:admin, message})
  end

  def init([%{cb: cb, args: args}]) do
    case Connection.connect() do
      {:ok, conn} ->
        state = %__MODULE__{cb: cb, conn: conn}
        run_callback(:init, args, state)
      error ->
        {:stop, error}
    end
  end

  def handle_cast({:admin, message}, state) do
    run_callback(:admin, message, state)
  end
  def handle_cast(_, state), do: {:noreply, state}

  def handle_info({:publish, topic, message}, state) do
    case MqttCall.decode(message) do
      {:ok, call} ->
        run_callback(:handle_call, topic, call.sender, call.endpoint, call.payload, state)
      _ ->
        case MqttCast.decode(message) do
          {:ok, cast} ->
            run_callback(:handle_cast, topic, cast.endpoint, cast.payload, state)
          _ ->
            case Poison.decode(message) do
              {:ok, message} ->
                run_callback(:handle_message, topic, message, state)
              {:error, error} ->
                Logger.error("Ignoring malformed message '#{inspect message}': #{inspect error}")
            end
        end
    end
  end

  def handle_info(_, state), do: {:noreply, state}

  defp run_callback(:init, args, state) do
    case state.cb.init(state.conn, args) do
      {:ok, cb_state} ->
        {:ok, %{state | cb_state: cb_state}}
      {:stop, reason} ->
        {:stop, reason}
      error ->
        {:stop, error}
    end
  end
  defp run_callback(:admin, message, state) do
    case state.cb.handle_admin(message, state.cb_state) do
      {:noreply, cb_state} ->
        {:noreply, %{state | cb_state: cb_state}}
      {:stop, reason} ->
        {:stop, reason}
      error ->
        {:stop, error}
    end
  end

  defp run_callback(:handle_message, topic, message, state) do
    case state.cb.handle_message(state.conn, topic, message, state.cb_state) do
      {:reply, topic, message, cb_state} ->
        Connection.publish(state.conn, message, routed_by: topic)
        {:noreply, %{state | cb_state: cb_state}}
      {:noreply, cb_state} ->
        {:noreply, %{state | cb_state: cb_state}}
      {:stop, reason} ->
        {:stop, reason}
      error ->
        {:stop, error}
    end
  end
  defp run_callback(:handle_cast, topic, endpoint, message, state) do
    case state.cb.handle_cast(state.conn, topic, endpoint, message, state.cb_state) do
      {:noreply, cb_state} ->
        {:noreply, %{state | cb_state: cb_state}}
      {:stop, reason} ->
        {:stop, reason}
      error ->
        {:stop, error}
    end
  end

  defp run_callback(:handle_call, topic, sender, endpoint, call, state) do
    case state.cb.handle_call(state.conn, topic, sender, endpoint, call, state.cb_state) do
      {:reply, {:ok, result}, cb_state} ->
        reply = %MqttReply{flag: "ok", result: [result]}
        Connection.publish(state.conn, reply, routed_by: sender)
        {:noreply, %{state | cb_state: cb_state}}
      {:reply, {:error, result}, cb_state} ->
        reply = %MqttReply{flag: "error", result: [result]}
        Connection.publish(state.conn, reply, routed_by: sender)
        {:noreply, %{state | cb_state: cb_state}}
      {:reply, result, cb_state} ->
        reply = %MqttReply{flag: "ok", result: [result]}
        Connection.publish(state.conn, reply, routed_by: sender)
        {:noreply, %{state | cb_state: cb_state}}
      {:stop, reason} ->
        {:stop, reason}
      error ->
        {:stop, error}
    end
  end

end
