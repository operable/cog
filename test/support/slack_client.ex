defmodule Cog.Test.Support.SlackClientState do

  def start_link() do
    Agent.start_link(fn -> fresh_state end, name: __MODULE__)
  end

  def set_start_time() do
    start_time = String.to_integer(String.slice("#{System.os_time}", 0, 10))
    Agent.update(__MODULE__, &(Map.put(&1, :start_time, start_time)))
  end

  def get_start_time() do
    Agent.get(__MODULE__, &(Map.get(&1, :start_time)))
  end

  def store_message(sender, message) do
    Agent.update(__MODULE__,
      fn(state) ->
        messages = Map.get(state, :messages)
        messages = Map.update(messages, sender, [message],
          fn(previous) ->
            Enum.sort([message|previous], &by_ts/2)
          end)
        Map.put(state, :messages, messages)
      end)
  end

  def get_messages(sender) do
    Agent.get(__MODULE__, fn(state) ->
      state
      |> Map.get(:messages)
      |> Map.get(sender)
    end)
  end

  def add_waiter(reply_from, caller) do
    add_callback(:waiters, reply_from, caller)
  end

  def get_waiters(reply_from) do
    get_callbacks(:waiters, reply_from)
  end

  def reset() do
    Agent.update(__MODULE__, fn(_) -> fresh_state end)
    set_start_time()
  end

  def fresh_state() do
    %{} |> Map.put(:messages, %{}) |> Map.put(:waiters, %{})
  end

  defp add_callback(key, reply_from, caller) do
    Agent.update(__MODULE__, fn(state) ->
      things = Map.fetch!(state, key)
      things = Map.update(things, reply_from, [caller],
        &([caller|&1]))
      Map.put(state, key, things) end)
  end

  defp get_callbacks(key, reply_from) do
    Agent.get_and_update(__MODULE__, fn(state) ->
      things = Map.fetch!(state, key)
      case Map.get(things, reply_from) do
        nil ->
          {nil, state}
        callers ->
          things = Map.delete(things, reply_from)
          state = Map.put(state, key, things)
          {callers, state}
      end
    end)
  end

  defp by_ts(first, second) do
    first.ts > second.ts
  end

end

defmodule Cog.Test.Support.SlackClient do

  @default_timeout 5000

  use Slack

  alias Cog.Test.Support.SlackClientState

  def new() do
    case System.get_env("SLACK_USER_API_TOKEN") do
      nil ->
        raise RuntimeError, message: "$SLACK_USER_API_TOKEN not set!"
      token ->
        {:ok, client} = start_link(token)
        :ok = initialize(client)
        {:ok, client}
    end
  end

  def initialize(client, room \\ nil) do
    call(client, {:init, room})
  end

  def reset(client) do
    call(client, :reset)
  end

  def chat_wait!(client, opts) do
    room = Keyword.fetch!(opts, :room)
    message = Keyword.fetch!(opts, :message)
    reply_from = Keyword.fetch!(opts, :reply_from)
    edited = Keyword.get(opts, :edited)
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    call(client, {:chat_and_wait, room, message, reply_from, edited}, timeout)
  end

  def get_messages(client, sender) do
    call(client, {:get_messages, sender})
  end

  def get_messages(client, sender, count) do
    case get_messages(client, sender) do
      {:ok, messages} ->
        Enum.take(messages, count)
      error ->
        error
    end
  end

  def handle_message(%{subtype: "message_changed"}, _state) do
    :ok
  end
  def handle_message(%{type: "message"}=message, state) do
    if message.user != state.me.id do
      msg = parse_message(message, state)
      SlackClientState.store_message(message.user, msg)
      case SlackClientState.get_waiters(message.user) do
        nil ->
          :ok
        callers ->
          reply = {:ok, msg}
          Enum.each(callers, fn({ref, caller}) -> send(caller, {ref, reply}) end)
      end
    end
    :ok
  end
  def handle_message(_message, _state) do
    :ok
  end

  def handle_info({{ref, sender}, {:init, room}}, state) do
    SlackClientState.start_link()
    SlackClientState.set_start_time()
    reply = if room != nil do
      result = Slack.Web.Channels.join(room, %{token: state.token, as_user: true})
      if result["ok"] == true do
        :ok
      else
        {:error, result["error"]}
      end
    else
      :ok
    end
    send(sender, {ref, reply})
    {:noreply, state}
  end
  def handle_info({{ref, sender}=caller, {:chat_and_wait, room, message, reply_from, nil}}, state) do
    result = Slack.Web.Chat.post_message(room, %{as_user: true, text: message, token: state.token, parse: :full})
    case result["ok"] do
      false ->
        send(sender, {ref, {:error, result["error"]}})
        {:noreply, state}
      true ->
        user_id = find_user(reply_from, state)
        SlackClientState.add_waiter(user_id, caller)
        {:noreply, state}
    end
  end
  def handle_info({{ref, sender}=caller, {:chat_and_wait, room, message, reply_from, edited}}, state) do
    result = Slack.Web.Chat.post_message(room, %{as_user: true, text: message, token: state.token})
    case result["ok"] do
      false ->
        send(sender, {ref, {:error, result["error"]}})
        {:noreply, state}
      true ->
        result = Slack.Web.Chat.update(result["channel"], edited, result["ts"], %{token: state.token, as_user: true, parse: :full})
        case result["ok"] do
          false ->
            send(sender, {ref, {:error, result["error"]}})
            {:noreply, state}
          true ->
            user_id = find_user(reply_from, state)
            SlackClientState.add_waiter(user_id, caller)
            {:noreply, state}
        end
    end
  end
  def handle_info({{ref, sender}, {:get_messages, chat_user}}, state) do
    user_id = find_user(chat_user, state)
    messages = SlackClientState.get_messages(user_id)
    send(sender, {ref, {:ok, messages}})
    {:noreply, state}
  end
  def handle_info({{ref, sender}, :reset}, state) do
    SlackClientState.reset()
    send(sender, {ref, :ok})
    {:noreply, state}
  end

  defp call(sender, data, timeout \\ @default_timeout) do
    ref = :erlang.make_ref()
    message = {{ref, self()}, data}
    send(sender, message)
    receive do
      {^ref, result} ->
        result
    after timeout ->
        {:error, :timeout}
    end
  end

  defp find_user(name, state) do
    result = Slack.Web.Users.list(%{token: state.token})
    Enum.find(result["members"], &(Map.get(&1, "name") == name)) |> Map.get("id")
  end

  defp parse_message(%{attachments: [attachment|_], ts: ts}=message, state) do
    make_message(attachment.text, ts, location(message, state))
  end
  defp parse_message(%{text: text, ts: ts}=message, state) do
    make_message(text, ts, location(message, state))
  end

  defp make_message(text, ts, locn) do
    [realtime, _] = String.split(ts, ".", parts: 2)
    %{ts: ts, real_time: String.to_integer(realtime), text: text, location: locn}
  end

  defp location(%{channel: %{is_im: true}}, _state) do
    %{type: :im}
  end
  defp location(%{channel: id}, state) do
    case id do
      <<"D", _::binary>> ->
        %{type: :im}
      <<"G", _::binary>> ->
        group = Slack.Web.Groups.info(id, %{token: state.token})
        group = group["group"]
        %{type: :group,
          name: Map.get(group, "name")}
      _ ->
        channel = Slack.Web.Channels.info(id, %{token: state.token})
        channel = channel["channel"]
        %{type: :channel,
          name: Map.get(channel, "name")}
    end
  end

end
