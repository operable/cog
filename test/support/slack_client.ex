defmodule Cog.Test.Support.SlackClientState do

  def start_link() do
    Agent.start_link(fn -> fresh_state end, name: __MODULE__)
  end

  def store_message(sender, message) do
    Agent.update(__MODULE__,
      fn(state) ->
        messages = state
        |> Map.get(:messages)
        |> Map.update(sender, [message],
          fn(previous) ->
            Enum.sort([message|previous], &by_ts/2)
          end)
        Map.put(state, :messages, messages)
      end)
  end

  def add_waiter(reply_from, caller) do
    Agent.update(__MODULE__, fn(state) ->
      updated = state
      |> Map.fetch!(:waiters)
      |> Map.update(reply_from, [caller], &([caller|&1]))

      Map.put(state, :waiters, updated)
    end)
  end

  def get_waiters(reply_from) do
    Agent.get_and_update(__MODULE__, fn(state) ->
      things = Map.fetch!(state, :waiters)
      case Map.get(things, reply_from) do
        nil ->
          {nil, state}
        callers ->
          things = Map.delete(things, reply_from)
          state = Map.put(state, :waiters, things)
          {callers, state}
      end
    end)
  end

  def fresh_state() do
    %{messages: %{},
      waiters: %{}}
  end

  defp by_ts(first, second) do
    first.ts > second.ts
  end

end

defmodule Cog.Test.Support.SlackClient do

  # To avoid Slack throttling
  @api_wait_interval 1_000
  defp api_wait(),
    do: :timer.sleep(@api_wait_interval)

  # Be a little more liberal with the timeouts to account for
  # potentially several Slack API calls.
  @default_timeout 10_000

  use Slack

  alias Cog.Test.Support.SlackClientState

  def new() do
    # Remember; this isn't the bot, this is the *user*
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

  def chat_wait!(client, opts) do
    room = Keyword.fetch!(opts, :room)
    message = Keyword.fetch!(opts, :message)
    reply_from = Keyword.fetch!(opts, :reply_from)
    edited = Keyword.get(opts, :edited)
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    call(client, {:chat_and_wait, room, message, reply_from, edited}, timeout)
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
    reply = if room != nil do
      api_wait()
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
    api_wait()
    result = Slack.Web.Chat.post_message(room, %{as_user: true, text: message, token: state.token, parse: :full})
    case result["ok"] do
      false ->
        send(sender, {ref, {:error, result["error"]}})
        {:noreply, state}
      true ->
        user_id = find_user_id!(reply_from, state)
        SlackClientState.add_waiter(user_id, caller)
        {:noreply, state}
    end
  end
  def handle_info({{ref, sender}=caller, {:chat_and_wait, room, message, reply_from, edited}}, state) do
    api_wait()
    result = Slack.Web.Chat.post_message(room, %{as_user: true, text: message, token: state.token})
    case result["ok"] do
      false ->
        send(sender, {ref, {:error, result["error"]}})
        {:noreply, state}
      true ->
        api_wait()
        result = Slack.Web.Chat.update(result["channel"], edited, result["ts"], %{token: state.token, as_user: true, parse: :full})
        case result["ok"] do
          false ->
            send(sender, {ref, {:error, result["error"]}})
            {:noreply, state}
          true ->
            user_id = find_user_id!(reply_from, state)
            SlackClientState.add_waiter(user_id, caller)
            {:noreply, state}
        end
    end
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

  defp find_user_id!(name, slack) do
    users = Map.values(slack.users)
    case Enum.find(users, fn(u) -> Map.get(u, :name) == name end) do
      nil ->
        raise RuntimeError, message: "Couldn't find a user with the Slack name #{name}"
      user ->
        Map.get(user, :id)
    end
  end

  defp find_user_name!(id, slack) do
    case get_in(slack, [:users, id]) do
      nil ->
        raise RuntimeError, message: "Couldn't find a user with the Slack id #{id}"
      user ->
        Map.get(user, :name)
    end
  end

  defp parse_message(%{attachments: [attachment|_], ts: ts}=message, state) do
    make_message(attachment.text, ts, location(message, state))
  end
  defp parse_message(%{text: text, ts: ts}=message, state) do
    make_message(resolve_references(text, state),
                 ts,
                 location(message, state))
  end

  # In a few places, we get Slack user IDs in our messages... it's
  # nicer for readable tests to just match against the names, as they
  # would be rendered in a "smart" client
  @user_regex ~r/<\@(U.*)(\|(.*))?>/U
  defp resolve_references(text, state) do
    replace(text, @user_regex, fn original ->
      case Regex.run(@user_regex, original) do
        [^original, user_id] ->
          "@" <> find_user_name!(user_id, state)
        [^original, _user_id, _right, user_name] ->
          "@" <> user_name
      end
    end)
  end

  defp replace(message, regex, replace_fun) do
    case Regex.run(regex, message, return: :index) do
      nil ->
        message
      [{start, length}|_] ->
        original = String.slice(message, start, length)
        replacement = replace_fun.(original)

        {left, right} = String.split_at(message, start)
        right = String.slice(right, length, String.length(right))
        replace(left <> replacement <> right, regex, replace_fun)
    end
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
        api_wait()
        group = Slack.Web.Groups.info(id, %{token: state.token})
        group = group["group"]
        %{type: :group,
          name: Map.get(group, "name")}
      _ ->
        api_wait()
        channel = Slack.Web.Channels.info(id, %{token: state.token})
        channel = channel["channel"]
        %{type: :channel,
          name: Map.get(channel, "name")}
    end
  end

end
