defmodule Cog.Adapters.Slack.RTMConnector do

  # ping periodically so Slack knows we're still here
  @ping_interval 30000 # 30 seconds
  @send_chat_message_timeout 5000 # 5 seconds
  @channel_events ["channel_joined", "channel_left", "channel_deleted",
                   "channel_rename", "channel_archive", "channel_unarchive",
                   "group_joined", "group_left", "group_close", "group_archive",
                   "group_unarchive", "group_rename"]

  @typedoc """
  Custom state struct for the Slack `gen_server`-esque Websocket client.

  See [the Slack library] for more.

  ## Fields

  * `:id` - The ID of the bot user, e.g. `"U023BECGF"`
  * `:direct_name` - The bot username formatted as a mention,
    e.g. `"@cog"`. This is how mentions look after they are unescaped; we'll
    need it to figure out when someone is talking directly to the bot.
  * `:name` - The name of the bot user, without the "@", e.g. `"cog"`

  [the Slack library]: https://github.com/BlakeWilliams/Elixir-Slack

  """
  @type state :: %__MODULE__{id: String.t,
                             direct_name: String.t,
                             name: String.t}
  defstruct [id: nil,
             direct_name: nil,
             name: nil]

  require Logger
  use Slack
  alias Cog.Adapters.Slack, as: SlackAdapter

  ########################################################################
  # Public API

  # We don't have any initial state per se; everything we care about
  # is available in `handle_connect/2`
  @initial_state nil

  ########################################################################
  # Slack callbacks
  #
  # Slack-Elixir defines the following overridable callback
  # implementations:
  #
  # * handle_connect/2
  # * handle_message/3
  # * handle_close/3
  # * handle_info/3

  @doc """
  Initializes our state.
  """
  def handle_connect(slack, @initial_state) do
    state = %__MODULE__{id: slack.me.id,
                        name: slack.me.name,
                        direct_name: "@" <> slack.me.name}
    :erlang.register(__MODULE__, self())
    Logger.info("Ready. Slack username: #{slack.me.name}, userid: #{slack.me.id}.")

    # TODO: do we want to capture the timer reference for anything?
    {:ok, _timer_ref} = :timer.send_interval(@ping_interval, :send_ping)
    {:ok, state}
  end

  def handle_message(%{type: "message", user: user_id, channel: channel, text: text}, _slack, state) do
    text = SlackAdapter.Formatter.unescape(text)

    case invocation_type(user_id, channel, text, state) do
      :ignore ->
        {:ok, state}
      {:direct, room} ->
        # Someone's talking directly to the bot 1-on-1
        handle_direct_command(room, user_id, text, state)
      {:mention, room} ->
        # Command invocation by mention, e.g. "@bot run-command"
        handle_mention_command(room, user_id, text, state)
      {:prefix, room} ->
        # Using special prefix, e.g. "!run-command"
        handle_command(room, user_id, text, state)
    end
  end
  # Called when a user edits a previous command
  def handle_message(%{channel: channel, type: "message", message: %{edited: _info, text: text, user: user_id}}, _slack, state) do
    text = SlackAdapter.Formatter.unescape(text)

    {:ok, user} = SlackAdapter.API.lookup_user(id: user_id)
    {message, handler} = case invocation_type(user_id, channel, text, state) do
                           :ignore ->
                             {nil, fn() -> {:ok, state} end}
                           {:direct, room} ->
                             {"Executing edited command '#{text}'",
                               fn() -> handle_direct_command(room, user_id, text, state) end}
                           {:mention, room} ->
                             {"@#{user.handle} Executing edited command '#{remove_mention(text, state)}'",
                               fn() -> handle_mention_command(room, user_id, text, state) end}
                           {:prefix, room} ->
                             {"@#{user.handle} Executing edited command '#{remove_mention(text, state)}'",
                              fn() -> handle_command(room, user_id, text, state) end}
                         end
    unless message == nil do
      SlackAdapter.API.send_message(%{"id" => channel}, message)
    end
    handler.()
  end
  def handle_message(%{type: channel_event, channel: channel}, _slack, state) when channel_event in @channel_events do
    channel_id = case channel do
      channel when is_binary(channel) ->
        channel
      %{id: id} ->
        id
    end

    SlackAdapter.API.expire_channel(channel_id)
    {:ok, state}
  end
  def handle_message(_message, _slack, state) do
    {:ok, state}
  end

  @doc """
  Handle raw messages sent to this process. This is how we receive
  messages from our command bus.
  """
  def handle_info(:send_ping, slack, state) do
    # We send ourselves this message periodically in order to keep the
    # connection with Slack alive
    {:ok, json} = Poison.encode(%{type: "ping"})
    send_raw(json, slack)
    {:ok, state}
  end
  def handle_info({{:send_message, ref, sender}, room, message}, _slack, state) do
    SlackAdapter.API.send_message(room, message)
    send(sender, {ref, :ok})
    {:ok, state}
  end
  def handle_info({:assigned_userid, ref, sender}, _slack, state) do
    send(sender, {ref, {:ok, state.id}})
    {:ok, state}
  end
  def handle_info(info, _slack, state) do
    Logger.info("#{inspect __MODULE__}: received unexpected message: #{inspect info}")
    {:ok, state}
  end

  ########################################################################
  # Helpers

  # Handle commands that are invoked with a special command prefix
  #
  # Example:
  #
  #     !do-something
  #
  # Only works if `:enable_spoken_commands` is not explicitly
  # disabled.
  defp handle_command(room, user_id, text, state) do
    case Application.get_env(:cog, :enable_spoken_commands, true) do
      false ->
        {:ok, state}
      true ->
        text = Regex.replace(~r/^#{Regex.escape(command_prefix)}/, text, "")
        forward_command(room, user_id, text, state)
    end
  end

  # One-on-one commands in direct chat
  #
  # The same as `forward_command/4`, since we shouldn't need to do any
  # stripping before putting the command on the bus
  defp handle_direct_command(room, user_id, text, state),
   do: forward_command(room, user_id, text, state)

  # Respond to commands invoked via mention. Strips off the mention to
  # get the raw command and passes it on to the command bus.
  #
  # Example:
  #
  #     @bot do-something
  defp handle_mention_command(room, user_id, text, state) do
    text = remove_mention(text, state)
    forward_command(room, user_id, text, state)
  end

  # Take a raw command text (stripped of any bot mentions or command
  # prefixes) and place it on the command bus
  defp forward_command(room, user_id, text, state) do
    {:ok, sender} = SlackAdapter.API.lookup_user(id: user_id)
    SlackAdapter.receive_message(sender, room, text)
    {:ok, state}
  end

  # Define the prefix used when `:enable_spoken_commands` is active.
  defp command_prefix,
    do: Application.get_env(:cog, :command_prefix, "!")

  defp remove_mention(text, state) do
    ["", text] = String.split(text, state.direct_name)
    Regex.replace(~r/^:\s*/, text, "")
  end

  defp invocation_type(user_id, channel, text, state) do
    case user_id == state.id do
      true ->
        :ignore
      false ->
        # Determine how to respond based on what kind of message it is
        {:ok, room} = SlackAdapter.API.lookup_room(id: channel)
        first_word = String.split(text, " ", parts: 2) |> :erlang.hd |> String.replace_suffix(":", "")
        cond do
          room.name == "direct" ->
            {:direct, room}
          first_word == state.direct_name ->
            {:mention, room}
          String.starts_with?(first_word, command_prefix) ->
            {:prefix, room}
          true ->
            :ignore
        end
    end
  end

end
