defmodule Cog.Command.GenCommand do
  @moduledoc """
  Generic bot command support.

  Elixir-based commands should see `Cog.Command.GenCommand.Base`, as it
  provides several helper macros that remove much of the boilerplate
  from implementation, and also provides several helpful compile-time
  validity checks.

  If you are implementing a pure Erlang command, however, you can just
  implement this behaviour directly as one normally does.
  """

  @typedoc """
  The state supplied to the callback module implementation
  functions. This will be created by `callback_module.init/2`,
  maintained by the `GenCommand` infrastructure, and passed into
  `handle_message/2`
  """
  @type callback_state() :: term()

  @typedoc """
  Used to indicate which topic on the message bus replies should be
  posted to.
  """
  @type message_bus_topic() :: String.t

  @typedoc """
  The basename of the template file, used to render the json output into a text
  response.
  """
  @type template() :: String.t

  @typedoc """
  Commands and services can send back arbitrary responses (as long
  as they can serialize to JSON).
  """
  @type command_response() :: term()

  @doc """
  Initializes the callback module's internal state.
  """
  @callback init(term())
            :: {:ok, callback_state()} |
               {:error, term()}

  @callback handle_message(Command.Request.t, callback_state())
            :: {:reply, message_bus_topic(), command_response(), callback_state()} |
               {:reply, message_bus_topic(), template(), command_response(), callback_state()} |
               {:error, message_bus_topic(), String.t, callback_state()} |
               {:noreply, callback_state()}

  @doc """
  Returns `true` if `module` implements the
  `#{inspect __MODULE__}` behaviour.
  """
  def is_command?(module) do
    attributes = try do
                   # Only Elixir modules have `__info__`
                   module.__info__(:attributes)
                 rescue
                   UndefinedFunctionError ->
                     # Erlang modules use `module_info`
                     module.module_info(:attributes)
                 end
    behaviours = Keyword.get(attributes, :behaviour, [])
    __MODULE__ in behaviours
  end

  ########################################################################
  # Implementation

  use GenServer

  require Logger

  ## Fields
  #
  # * `mq_conn`: Connection to the message bus
  # * `cb_module`: callback module; the module implementing the specific
  #   command details
  # * `cb_state`: An arbitrary term for when the callback module needs
  #   to keep state of its own. Initial value is whatever
  #   `cb_module:init/1` returns.
  # * `topic`: message bus topic to which commands are sent; this is
  #   what we listen to to get jobs.
  @typep state :: %__MODULE__{mq_conn: Carrier.Messaging.Connection.connection,
                              cb_module: module(),
                              cb_state: callback_state(),
                              topic: String.t}
  defstruct [mq_conn: nil,
             cb_module: nil,
             cb_state: nil,
             command_name: nil,
             bundle_name: nil,
             topic: nil]

  @doc """
  Starts the command.

  ## Arguments

  * `bundle`: the name of the command's enclosing bundle
  * `command`: the name of the command itself
  * `module`: the module implementing the command
  * `args`: will be passed to `module.info/1` to generate callback
    state
  """
  def start_link(bundle, command, module, args) do
    GenServer.start_link(__MODULE__, [bundle: bundle, command: command,
                                      module: module, args: args])
  end

  @doc """
  Callback for the underlying `GenServer` implementation of
  `GenCommand`. Calls `module.init/2` to set up callback state.

  """
  @spec init(Keyword.t) :: {:ok, Cog.Command.GenCommand.state} | {:error, term()}
  def init([bundle: bundle, command: command, module: module, args: args]) do
    # Trap exits for if / when the message bus connection dies; see
    # handle_info/2 for more
    :erlang.process_flag(:trap_exit, true)

    # Establish a connection to the message bus and subscribe to
    # the appropriate topics
    case Carrier.Messaging.Connection.connect do
      {:ok, conn} ->
        relay_id = Cog.Config.embedded_relay()
        [topic, reply_topic] = topics = [command_topic(bundle, command, relay_id),
                                         command_reply_topic(bundle, command, relay_id)]
        for topic <- topics do
          Logger.debug("#{inspect module}: Command subscribing to #{topic}")
          Carrier.Messaging.Connection.subscribe(conn, topic)
        end

        args = [{:bundle, bundle}, {:command, command}|args]
        case module.init(args) do
          {:ok, state} ->
            {:ok, %__MODULE__{bundle_name: bundle,
                              mq_conn: conn,
                              cb_module: module,
                              cb_state: state,
                              topic: topic}}
          {:error, reason} = error ->
            Logger.error("#{inspect module}: Command initialization failed: #{inspect reason}")
            {:stop, error}
        end
      {:error, reason} = error ->
        Logger.error("Command initialization failed: #{inspect reason}")
        {:stop, error}
    end
  end

  def handle_info({:publish, topic, message},
                  %__MODULE__{topic: topic, cb_module: cb_module}=state) do
    try do
      payload = Cog.Messages.Command.decode!(message)
      process_message(payload, cb_module, state)
    rescue
      e in Conduit.ValidationError ->
        # Obviously couldn't parse this as a proper Message... try to do
        # it as just JSON
        payload = Poison.decode!(message)
        send_error_reply(e.message, payload["reply_to"], state)
        {:noreply, state}
    end
  end
  def handle_info({:EXIT, conn, {:shutdown, reason}}, %__MODULE__{mq_conn: conn}=state) do
    Logger.error("Message bus connection died: #{inspect reason}")
    # Sleep a bit to make supervisor-initiated restarts have some
    # meaningful effect in the face of network hiccups; otherwise,
    # we'd burn through all of them too fast.
    :timer.sleep(2000) # milliseconds
    {:stop, :shutdown, state}
  end
  def handle_info(_, state),
    do: {:noreply, state}

  ########################################################################

  defp process_message(req, cb_module, state) do
    try do
      case cb_module.handle_message(req, state.cb_state) do
        {:reply, reply_to, template, reply, cb_state} ->
          new_state = %{state | cb_state: cb_state}
          send_ok_reply(reply, template, reply_to, new_state)
          {:noreply, new_state}
        {:reply, reply_to, reply, cb_state} ->
          new_state = %{state | cb_state: cb_state}
          send_ok_reply(reply, reply_to, new_state)
          {:noreply, new_state}
        {:error, reply_to, error_message, cb_state} ->
          new_state = %{state | cb_state: cb_state}
          send_error_reply(error_message, reply_to, new_state)
          {:noreply, new_state}
        {:noreply, cb_state} ->
          new_state = %{state | cb_state: cb_state}
          {:noreply, new_state}
      end
    rescue
      error ->
        message = format_error_message(req.command, error, System.stacktrace)
        send_error_reply(message, req.reply_to, state)
        {:noreply, state}
    end
  end

  ########################################################################

  defp send_error_reply(error_message, reply_to, state) when is_binary(error_message) do
    resp = %Cog.Messages.CommandResponse{status: "error",
                                         status_message: error_message}
    Carrier.Messaging.Connection.publish(state.mq_conn, resp, routed_by: reply_to)
  end

  ########################################################################

  defp send_ok_reply(reply, template, reply_to, state) when is_map(reply) or is_list(reply) or is_nil(reply) do
    resp = %Cog.Messages.CommandResponse{status: "ok",
                                         body: reply,
                                         template: template}
    Carrier.Messaging.Connection.publish(state.mq_conn, resp, routed_by: reply_to)
  end

  defp send_ok_reply(reply, reply_to, state) when is_map(reply) or is_list(reply) or is_nil(reply) do
    resp = %Cog.Messages.CommandResponse{status: "ok",
                                         body: reply}
    Carrier.Messaging.Connection.publish(state.mq_conn, resp, routed_by: reply_to)
  end
  defp send_ok_reply(reply, reply_to, state),
    do: send_ok_reply(%{body: [reply]}, reply_to, state)

  ########################################################################

  defp command_topic(bundle_name, command_name, relay_id),
    do: "/bot/commands/#{relay_id}/#{bundle_name}/#{command_name}"

  defp command_reply_topic(bundle_name, command_name, relay_id),
    do: "#{command_topic(bundle_name, command_name, relay_id)}/reply"

  defp format_error_message(command, error, stacktrace) do
    """

    It appears that the `#{command}` command crashed while executing, with the following error:

   ```#{inspect error}```

   Here is the stacktrace at the point where the crash occurred. This information can help the authors of the command determine the ultimate cause for the crash.

   ```#{inspect stacktrace, pretty: true}```
   """
  end

end
