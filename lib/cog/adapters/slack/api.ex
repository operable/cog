defmodule Cog.Adapters.Slack.API do
  require Logger
  use GenServer

  defstruct token: nil, ttl: nil

  @default_ttl 900
  @slack_api "https://slack.com/api/"
  @server_name :slack_api
  @user_cache :slack_api_users
  @channel_cache :slack_api_channels
  @direct_chat_channel_cache :slack_im

  def start_link(token, ttl) do
    GenServer.start_link(__MODULE__, [token, ttl], name: @server_name)
  end

  def lookup_user(key) when is_tuple(hd(key)) do
    case query_cache(@user_cache, key) do
      nil ->
        GenServer.call(@server_name, {:lookup_user, key}, :infinity)
      entry ->
        {:ok, entry}
    end
  end

  def lookup_room(name: "direct") do
    {:error, :badarg}
  end
  def lookup_room([id: <<"D", _::binary>> = id]) do
    {:ok, %{id: id, name: "direct"}}
  end
  def lookup_room(key) when is_tuple(hd(key)) do
    case query_cache(@channel_cache, key) do
      nil ->
        GenServer.call(@server_name, {:lookup_room, key}, :infinity)
      entry ->
        {:ok, entry}
    end
  end

  @doc """
  Resolve redirect destinations.

  NOTE: Only called (in this form) from the executor for finding redirects.
  """
  def lookup_room(id, as_user: _unused_pending_refactor) do
    case remove_brackets_if_present_from(id) do
      "@" <> user_id ->
        # If the user really exists, `user_id` will be an internal
        # Slack identifier. If not, `user_id` will be the whatever
        # name the end-user typed.
        lookup_direct_room(user_id: user_id, as_user: :unused_pending_refactor)
      "#" <> room_id ->
        # Similarly, if the room really exists, `room_id` will be an
        # internal Slack identifier.
        lookup_room(id: room_id)
      other ->
        # We do some snazzy recovery by not actually requiring the
        # end-user to preface user or room names with "@" or "#",
        # respectively (we can do this because we only accept room or
        # user names in specific places in pipeline invocations). In
        # this case, Slack of course won't have translated to internal
        # IDs, so we'll need to do that ourselves.
        #
        # First, we try the string as a room name, and if that fails,
        # fall back to treating it as a user name. If neither works,
        # we fail.
        case GenServer.call(@server_name, {:lookup_room, [name: other]}, :infinity) do
          {:ok, room} ->
            {:ok, room}
          {:error, :not_a_member} ->
            # We know the room exists, but we're not a member, so bail now
            {:error, :not_a_member}
          {:error, :not_found} ->
            case GenServer.call(@server_name, {:lookup_user, [handle: other]}, :infinity) do
              {:ok, user} ->
                lookup_direct_room(user_id: user.id, as_user: :unused_pending_refactor)
              {:error, _}=error ->
                error
            end
        end
    end
  end

  def lookup_direct_room(user_id: id, as_user: _old_unused_arg_pending_refactoring) do
    case query_cache(@direct_chat_channel_cache, [id: id]) do
      nil ->
        GenServer.call(@server_name, {:open_direct_chat, id}, :infinity)
      entry ->
        {:ok, entry}
    end
  end

  def send_message(room: room, text: text, as_user: as_user) do
    GenServer.call(@server_name, {:send_message, [room: room, text: text, as_user: as_user]}, :infinity)
  end

  def retrieve_last_message(room: room, oldest: oldest) do
    {:ok, %{id: room_id}} = lookup_room(name: room)
    GenServer.call(@server_name, {:retrieve_last_message, [room: room_id, oldest: oldest]}, :infinity)
  end

  def init([token, ttl]) when is_integer(ttl) or ttl == nil do
    case verify_token(token) do
      false ->
        {:error, :bad_slack_token}
      true ->
        :ets.new(@user_cache, [:named_table, {:read_concurrency, true}])
        :ets.new(@channel_cache, [:named_table, {:read_concurrency, true}])
        :ets.new(@direct_chat_channel_cache, [:named_table, {:read_concurrency, true}])
        state = case ttl do
                  nil ->
                    %__MODULE__{token: token, ttl: @default_ttl}
                  _ ->
                    %__MODULE__{token: token, ttl: ttl}
                end
        Logger.info("#{__MODULE__} initialized. Response cache TTL is #{state.ttl} seconds.")
        {:ok, state}
    end
  end

  def handle_call({:lookup_user, [id: id]}, _from, state) do
    case call_api!("users.info", state.token, body: %{user: id},
                   parser: &parse_user_result/1) do
      {:ok, handle} ->
        user = %{id: id, handle: handle}
        expiry = Cog.Time.now() + state.ttl
        :ets.insert(@user_cache, {id, {user, expiry}})
        {:reply, {:ok, user}, state}
      error ->
        {:reply, error, state}
    end
  end
  def handle_call({:lookup_user, [handle: handle]}, _from, state) do
    case call_api!("users.list", state.token, parser: &(parse_users_result(&1, handle, state))) do
      {:ok, user} ->
        {:reply, {:ok, user}, state}
      error ->
        {:reply, error, state}
    end
  end
  def handle_call({:lookup_room, [id: id]}, _from, state) do
    result = call_api!("channels.info", state.token, body: %{channel: id})
    reply = if result["ok"] do
      channel = result["channel"]
      true = maybe_cache_channel(channel, state.ttl)
      if is_member?(channel) do
        {:ok, channel_cache_item(channel)}
      else
        {:error, :not_a_member}
      end
    else
      {:error, result["error"]}
    end
    {:reply, reply, state}
  end
  def handle_call({:lookup_room, [name: name]}, _from, state) do
    result = call_api!("channels.list", state.token, body: %{exclude_archived: 1})
    reply = if result["ok"] do
      channels = result["channels"]
      Enum.each(channels, &maybe_cache_channel(&1, state.ttl))

      case Enum.find(channels, &is_channel_named?(&1, name)) do
        channel when is_map(channel) ->
          if is_member?(channel) do
            # Return what would come out of the cache if
            # we'd found it there in the first place
            {:ok, channel_cache_item(channel)}
          else
            {:error, :not_a_member}
          end
        nil ->
          {:error, :not_found}
      end
    else
      {:error, result["error"]}
    end
    {:reply, reply, state}
  end
  def handle_call({:open_direct_chat, user_id}, _from, state) do
    # In order for the bot to chat directly with a user, we need to
    # first open a chat channel with that user. This API method is
    # idempotent, so if a channel already exists with the given user,
    # we'll get the same channel reference back.
    #
    # See https://api.slack.com/methods/im.open
    result = call_api!("im.open", state.token, [body: %{user: user_id}])
    if result["ok"] do
      %{"id" => _channel_id} = response = result["channel"]
      cache_direct_chat(user_id, response, state.ttl)
      {:reply, {:ok, response}, state}
    else
      {:reply, {:error, translate_slack_error("im.open", result["error"])}, state}
    end
  end
  def handle_call({:send_message, [room: room, text: text, as_user: as_user]}, _from, state) do
    case call_api!("chat.postMessage", state.token, [body: %{channel: room, text: text, as_user: as_user}, parser: &parse_message(&1)]) do
      {:ok, message} ->
        {:reply, {:ok, message}, state}
      {:error, _error} ->
        {:reply, :error, state}
    end
  end
  def handle_call({:retrieve_last_message, [room: room, oldest: oldest]}, _from, state) do
    case call_api!("channels.history", state.token, [body: %{channel: room, oldest: oldest, count: 1}, parser: &parse_last_message(&1)]) do
      {:ok, message} ->
        {:reply, {:ok, message}, state}
      error ->
        {:reply, error, state}
    end
  end

  defp parse_users_result(result, query, state) do
    case result["ok"] do
      false ->
        {:error, result["error"]}
      true ->
        expiry = Cog.Time.now() + state.ttl
        case Enum.reduce(result["members"], nil,
                         fn(user, acc) ->
                           user_record = %{id: user["id"],
                                           handle: user["name"]}
                           :ets.insert(@user_cache, {user["id"], {user_record, expiry}})
                           :ets.insert(@user_cache, {user["name"], {user["id"], expiry}})
                           maybe_return_user(query, user_record, acc) end) do
          nil ->
            {:error, :not_found}
          value ->
            {:ok, value}
        end
    end
  end

  defp maybe_return_user(query, %{handle: query}=user, nil), do: user
  defp maybe_return_user(_query, _user, acc), do: acc

  defp is_channel_named?(%{"name" => name}, name),
    do: true
  defp is_channel_named?(_, _),
    do: false

  # Given a Slack channel object, return whether the API user (i.e.,
  # the bot) is a member.
  #
  # We can currently only redirect to channels that the bot is a
  # member of.
  defp is_member?(%{"is_member" => is_member}),
    do: is_member

  defp parse_user_result(result) do
    case result["ok"] do
      false ->
        {:error, result["error"]}
      true ->
        {:ok, result["user"]["name"]}
    end
  end

  defp parse_message(result) do
    case result["ok"] do
      false ->
        {:error, result["error"]}
      true ->
        {:ok, Map.put(result["message"], "ts", result["ts"])}
    end
  end

  defp parse_last_message(result) do
    case result["ok"] do
      false ->
        {:error, result["error"]}
      true ->
        case result["messages"] do
          [] ->
            {:ok, nil}
          [%{"text" => text}] ->
            {:ok, text}
        end
    end
  end

  # Caches the channel identifier under the user ID for future
  # retrievals. Although Slack does not document the details of direct
  # channel identifiers (how long they're valid, etc.), so far
  # they seem stable.
  defp cache_direct_chat(user_id, %{"id" => channel_id}=value, ttl) when is_binary(channel_id),
    do: :ets.insert(@direct_chat_channel_cache, {user_id, {value, expiration(ttl)}})

  # Only cache a channel if the bot is present in the channel
  #
  # May be a "channel object" (https://api.slack.com/types/channel)
  # from, e.g., "channels.info", or a limited channel object, from,
  # e.g., "channels.list"
  #(https://api.slack.com/methods/channels.list)
  #
  # In either case, they'll have the id, name, and membership information
  defp maybe_cache_channel(%{"is_member" => false}, _ttl),
    do: true
  defp maybe_cache_channel(%{"id" => id, "name" => name}=channel, ttl) do
    expiry = expiration(ttl)
    cache_item = channel_cache_item(channel)
    :ets.insert(@channel_cache, {id, {cache_item, expiry}})
    # TODO: do we want to cache the cache_item itself under name, too?
    :ets.insert(@channel_cache, {name, {id, expiry}})
  end

  # Given a Slack channel object
  # (https://api.slack.com/types/channel), pull out the data we care
  # about for our caching purposes.
  defp channel_cache_item(channel) when is_map(channel) do
    %{id: channel["id"],
      name: channel["name"]}
  end

  defp expiration(ttl),
    do: Cog.Time.now + ttl

  defp verify_token(token) do
    call_api!("auth.test", token, parser: &Map.get(&1, "ok"))
  end

  defp call_api!(method, token, opts) do
    body = Keyword.get(opts, :body)
    parser = Keyword.get(opts, :parser)
    {url, opts} = prepare_api_call(method, token, body)
    response = HTTPotion.get(url, opts)
    parse_result(Poison.decode!(response.body), parser)
  end

  defp parse_result(result, nil), do: result
  defp parse_result(result, f), do: f.(result)

  defp prepare_api_call(method, token, args) do
    url = build_url(method, token, args)
    {url, [headers: ["Accept": "application/json"]]}
  end

  defp build_url(method, token, args) do
    query = (args || %{})
    |> Dict.merge(token: token)
    |> URI.encode_query

    "#{@slack_api}#{method}?#{query}"
  end

  defp query_cache(cache, key) do
    key = extract_key(key)
    current_time = Cog.Time.now()
    case :ets.lookup(cache, key) do
      [] ->
        nil
      [{_, {_, expiry}}] when expiry < current_time ->
        nil
      [{_, {id, _}}] when is_binary(id) ->
        query_cache(cache, [id: id])
      [{_, {entry, _}}] when is_map(entry) ->
        entry
    end
  end

  defp extract_key([id: id]), do: id
  defp extract_key([name: name]), do: name
  defp extract_key([handle: handle]), do: handle


  # Translate Slack error strings to Elixir atoms
  #
  # im.open can also raise "not_authed", "invalid_auth", and
  # "account_inactive" errors, per the docs
  # (https://api.slack.com/methods/im.open), but there's no way the
  # application would get this far to have those show up here.
  defp translate_slack_error("im.open", "user_not_found"), do: :user_not_found
  defp translate_slack_error("im.open", "user_not_visible"), do: :user_not_visible
  defp translate_slack_error("im.open", "user_disabled"), do: :user_disabled

  # If a user mentions a real Slack room or user by name
  # (e.g. "#general", "@a_user_that_exists"), the message text that we
  # receive has these names converted into internal Slack identifiers,
  # rather than the names. Additionally, they are wrapped in brackets.
  #
  # Thus a mention of "#general" will come to us like "<#C00ABCDEF>",
  # and "@a_user_that_exists" like "<@U0A12ABCD>". If a user mentions
  # a room or user that doesn't exist, we'll just get the raw text:
  # "#not_a_real_room", "@easter_bunny", etc.
  #
  # In order to normalize things, we strip off any enclosing brackets
  # we may find.
  defp remove_brackets_if_present_from(id),
    do: String.replace(id, ~r/<([^>]*)>/, "\\1")

end
