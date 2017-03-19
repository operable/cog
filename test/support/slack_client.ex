defmodule Cog.Test.Support.SlackClientState do
  @moduledoc """
  Additional state to track for a `Cog.Test.Support.SlackClient`
  process. Ideally, we'd add this data to the client's state directly,
  but the Elixir-Slack library doesn't allow arbitrary data in its
  state. If it did, then this module could go away.
  """
  def start_link(),
    do: Agent.start_link(&fresh_state/0, name: __MODULE__)

  @doc """
  Record a timestamp for a message. The client should only process
  messages that have a timestamp greater than this one.
  """
  def set_cutoff_ts(ts),
    do: Agent.update(__MODULE__, &Map.put(&1, :cutoff_ts, ts))

  @doc """
  Retrieve the current "cutoff" timestamp. The client should only
  process messages that have a timestamp greater than this one.
  """
  def get_cutoff_ts(),
    do: Agent.get(__MODULE__, &Map.get(&1, :cutoff_ts))

  @doc """
  Record a test process as waiting for a response from Slack.

  `reply_from`: a Slack user. Only messages sent from this user are
                considered.
  `caller`: a tuple consisting of a unique ref and the test process
            waiting for a response.
  """
  def add_waiter(reply_from, {ref, pid}=caller)
  when is_reference(ref) and is_pid(pid) do
    Agent.update(__MODULE__,
                 &update_in(&1,
                            [:waiters, reply_from],
                            fn(nil) -> [caller]
                              (list) -> [caller|list]
                            end))
  end

  @doc """
  Retrieve the list of test processes waiting for a response sent from
  the Slack user `reply_from`.

  Returns nil if no one was waiting, but returns a list of waiters
  otherwise. Note: returned waiters are removed from the state.
  """
  def get_waiters(reply_from) do
    Agent.get_and_update(__MODULE__,
                         &get_and_update_in(&1,
                                            [:waiters, reply_from],
                                            fn(_) -> :pop end))
  end

  defp fresh_state(),
    do: %{waiters: %{}, cutoff_ts: 0}

end

defmodule Cog.Test.Support.SlackClient do

  # To avoid Slack throttling
  @api_wait_interval 1_500
  defp api_wait(),
    do: :timer.sleep(@api_wait_interval)

  # Be a little more liberal with the timeouts to account for
  # potentially several Slack API calls.
  @default_timeout (@api_wait_interval * 6) + 2_000

  use Slack

  alias Cog.Test.Support.SlackClientState

  def new() do
    # Remember; this isn't the bot, this is the *user*
    case System.get_env("SLACK_USER_API_TOKEN") do
      nil ->
        raise RuntimeError, message: "$SLACK_USER_API_TOKEN not set!"
      token ->
        :timer.sleep(@api_wait_interval * 2)
        try do
          {:ok, client} = start_link(token)
          :ok = initialize(client)
          {:ok, client}
        rescue
        e in RuntimeError ->
          if e.message =~ "You are sending too many requests. Please relax." do
            # In our current fork of the Elixir library, HTTP 429
            # responses aren't handled very gracefully. The mainline
            # library actually now returns an error tuple instead of
            # raising an exception, but in no case does it return the
            # value of the Retry-After HTTP header, which is the
            # number of seconds that you need to wait before
            # attempting to connect again.
            #
            # Absent some tweaking of the Slack library to return this
            # information, we can catch the exception our fork
            # currently throws and then sleeping manually. Manual
            # experiments with the API show that 60 seconds is a
            # typical value for the Retry-After header.
            #
            # Ideally, the Slack library would handle this throttling,
            # or at least return the Return-After header value to
            # callers, allowing them to determine how to
            # proceed. Until that time, we'll give this a shot.
            Logger.warn("Error connecting to Slack RTM endpoint: #{inspect e, pretty: true}")
            Logger.warn("Sleeping for a minute (and some change) and retrying")
            :timer.sleep(70_000)
            {:ok, client} = start_link(token)
            :ok = initialize(client)
            {:ok, client}
          else
            throw e
          end
        end
    end
  end

  def initialize(client),
    do: call(client, :init)

  def chat_wait!(client, opts) do
    room = Keyword.fetch!(opts, :room)
    message = Keyword.fetch!(opts, :message)
    reply_from = Keyword.fetch!(opts, :reply_from)
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    call(client, {:chat_and_wait, room, message, reply_from}, timeout)
  end

  def handle_message(%{type: "message"}=message, state) do
    # Only deal with messages that aren't sent by the user.... Really,
    # we only want to care about messages from the bot.
    if message.user != state.me.id do
      # The Elixir-Slack library converts Slack messages to atom-keyed
      # maps instead of string-keyed ones :/
      if String.to_float(message[:ts]) > SlackClientState.get_cutoff_ts() do
        msg = parse_message(message, state)
        waiters = SlackClientState.get_waiters(message.user)
        if waiters do
          Enum.each(waiters, fn({ref, caller}) ->
            send(caller, {ref, {:ok, msg}})
          end)
        end
      end
    end
    :ok
  end
  def handle_message(_message, _state),
    do: :ok

  def handle_info({{ref, sender}, :init}, state) do
    SlackClientState.start_link()
    send(sender, {ref, :ok})
    {:noreply, state}
  end
  def handle_info({{ref, sender}=caller, {:chat_and_wait, room, message, reply_from}}, state) do
    api_wait()
    result = Slack.Web.Chat.post_message(room, %{as_user: true,
                                                 text: message,
                                                 token: state.token,
                                                 parse: :full})
    if result["ok"] do
      result["ts"] # Yes, the keys are strings here
      |> String.to_float
      |> SlackClientState.set_cutoff_ts

      user_id = find_user_id!(reply_from, state)
      SlackClientState.add_waiter(user_id, caller)
    else
      send(sender, {ref, {:error, result["error"]}})
    end

    {:noreply, state}
  end

  defp call(sender, data, timeout \\ @default_timeout) do
    ref = make_ref()
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
    make_message(attachment.text, ts, location(message, state), nil)
  end
  defp parse_message(%{text: text, ts: ts}=message, state) do
    make_message(resolve_references(text, state),
                 ts,
                 location(message, state),
                 message[:thread_ts])
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

  defp make_message(text, ts, locn, thread_ts) do
    [realtime, _] = String.split(ts, ".", parts: 2)
    %{ts: ts, real_time: String.to_integer(realtime), text: text, location: locn, thread_ts: thread_ts}
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
