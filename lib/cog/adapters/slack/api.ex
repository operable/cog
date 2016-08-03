defmodule Cog.Adapters.Slack.API do
  use GenServer
  require Logger

  defstruct token: nil, ttl: nil

  @default_ttl 60 # 1 minute
  @slack_api "https://slack.com/api/"
  @server_name :slack_api
  @user_cache :slack_api_users
  @channel_cache :slack_api_channels
  @direct_chat_channel_cache :slack_im

  def start_link(config) do
    GenServer.start_link(__MODULE__, config, name: @server_name)
  end

  def send_message(%{"id" => id}, message) when is_binary(message) do
    GenServer.call(@server_name, {:send_message, id, message}, :infinity)
  end

  def lookup_user("@" <> handle),
    do: lookup_user(handle: handle)
  def lookup_user(handle) when is_binary(handle),
    do: lookup_user(handle: handle)
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
  def lookup_room("@" <> user_name) do
    with {:ok, user} <- lookup_user(handle: user_name),
      do: lookup_direct_room(user_id: user.id)
  end
  def lookup_room("#" <> channel_name),
    do: lookup_room(name: channel_name)
  def lookup_room(other) when is_binary(other),
    do: {:error, :ambiguous}

  def lookup_direct_room(user_id: id) do
    case query_cache(@direct_chat_channel_cache, [id: id]) do
      nil ->
        GenServer.call(@server_name, {:open_direct_chat, id}, :infinity)
      entry ->
        {:ok, entry}
    end
  end

  def expire_channel(channel_id) when is_binary(channel_id) do
    GenServer.call(@server_name, {:expire_channel, channel_id}, :infinity)
  end

  def init(config) do
    token = config[:api][:token]
    cache_ttl = config[:api][:cache_ttl] || @default_ttl

    case verify_token(token) do
      false ->
        {:error, :bad_slack_token}
      true ->
        :ets.new(@user_cache, [:named_table, {:read_concurrency, true}])
        :ets.new(@channel_cache, [:named_table, {:read_concurrency, true}])
        :ets.new(@direct_chat_channel_cache, [:named_table, {:read_concurrency, true}])

        Logger.info("Ready. Response cache TTL is #{cache_ttl} seconds.")

        {:ok, %__MODULE__{token: token, ttl: cache_ttl}}
    end
  end

  def handle_call({:send_message, room_id, message}, _from, state) do
    result = call_api!("chat.postMessage", state.token, body: %{channel: room_id, text: message, as_user: true, parse: "full"})
    reply = case result["ok"] do
      true ->
        {:ok, result["message"]}
      false ->
        {:error, result["error"]}
    end
    {:reply, reply, state}
  end

  def handle_call({:lookup_user, [id: id]}, _from, state) do
    result = call_api!("users.info", state.token, body: %{user: id})
    reply = if result["ok"] do
      cache_item = result["user"] |> cache(state.ttl)
      {:ok, cache_item}
    else
      {:error, result["error"]}
    end
    {:reply, reply, state}
  end
  def handle_call({:lookup_user, [handle: handle]}, _from, state) do
    # Only used to lookup users mentioned without an "@"
    result = call_api!("users.list", state.token, [])
    reply = if result["ok"] do
      {_cached, maybe_match} = Enum.map_reduce(result["members"], nil,
        fn(user, previous_match) ->
          cached = cache(user, state.ttl)
          if user["name"] == handle do
            {cached, cached}
          else
            {cached, previous_match}
          end
        end)

      case maybe_match do
        nil ->
          {:error, :not_found}
        value ->
          {:ok, value}
      end
    else
      {:error, result["error"]}
    end
    {:reply, reply, state}
  end

  # Group chat IDs start with "G"
  def handle_call({:lookup_room, [id: <<"G", _::binary>> = id]}, _from, state) do
    result = call_api!("groups.info", state.token,
                       # Yes, the key is 'channel' even though we're
                       # talking about groups
                       body: %{channel: id})
    reply = if result["ok"] do
      # TODO: if you get a group, you're always a member, right?
      group = result["group"] |> cache(state.ttl)
      {:ok, group}
    else
      {:error, result["error"]}
    end
    {:reply, reply, state}
  end
  def handle_call({:lookup_room, [id: id]}, _from, state) do
    result = call_api!("channels.info", state.token, body: %{channel: id})
    reply = if result["ok"] do
      channel = result["channel"]
      cached = cache(channel, state.ttl)
      {:ok, cached}
    else
      {:error, result["error"]}
    end
    {:reply, reply, state}
  end
  def handle_call({:lookup_room, [name: name]}, _from, state) do
    channels_result = call_api!("channels.list", state.token, body: %{exclude_archived: 1})
    groups_result   = call_api!("groups.list",   state.token, body: %{exclude_archived: 1})

    reply = if channels_result["ok"] and groups_result["ok"] do
      # We treat both channels and private groups as channels
      channels = channels_result["channels"] ++ groups_result["groups"]

      # Cache all the channels and return their cache representations
      cached = Enum.map(channels, &cache(&1, state.ttl))

      case Enum.find(cached, &is_channel_named?(&1, name)) do
        channel when not(is_nil(channel)) ->
          {:ok, channel}
        _ ->
          {:error, :not_found}
      end
    else
      {:error, channels_result["error"] || groups_result["error"]}
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
      direct_chat = result["channel"]
      cached = cache_direct_chat(user_id, direct_chat, state.ttl)
      {:reply, {:ok, cached}, state}
    else
      {:reply, {:error, translate_slack_error("im.open", result["error"])}, state}
    end
  end

  def handle_call({:expire_channel, channel_id}, _from, state) do
    expire_key(channel_id)
    {:reply, :ok, state}
  end

  defp is_channel_named?(%{name: name}, name), do: true
  defp is_channel_named?(%{"name" => name}, name), do: true
  defp is_channel_named?(_, _), do: false

  ########################################################################
  # Cache-related Functions

  # Cache Slack objects, keyed by id and name.
  #
  # Returns the value that was cached, which is a minimal version of
  # the input, reflecting just what we need. See cache_item/1 for more.
  #
  # Caches channels, groups, and users; see:
  # * https://api.slack.com/types/channel
  # * https://api.slack.com/types/group
  # * https://api.slack.com/types/user
  defp cache(%{"is_channel" => true, "id" => id, "name" => name}=channel, ttl) do
    expiry = expiration(ttl)
    cache_item = cache_item(channel)
    :ets.insert(@channel_cache, {id, {cache_item, expiry}})
    # TODO: do we want to cache the cache_item itself under name, too?
    :ets.insert(@channel_cache, {name, {id, expiry}})
    cache_item
  end
  defp cache(%{"is_group" => true, "id" => id, "name" => name}=group, ttl) do
    expiry = expiration(ttl)
    cache_item = cache_item(group)
    :ets.insert(@channel_cache, {id, {cache_item, expiry}})
    # TODO: do we want to cache the cache_item itself under name, too?
    :ets.insert(@channel_cache, {name, {id, expiry}})
    cache_item
  end
  defp cache(%{"id" => id, "name" => handle, "profile" => %{}}=user, ttl) do
    # Users don't have an "is_user" key, but they do have a profile
    expiry = expiration(ttl)
    cache_item = cache_item(user)
    :ets.insert(@user_cache, {id, {cache_item, expiry}})
    # TODO: do we want to cache the cache_item itself under name, too?
    :ets.insert(@user_cache, {handle, {id, expiry}})
    cache_item
  end

  # Conceptually the same as `cache/2`, but Slack's `im.open` method
  # doesn't actually return an `im` object; if it did, we'd have the
  # channel id and the user ID in one place. As it is, we supply that
  # information ourselves
  #
  # See:
  # * https://api.slack.com/methods/im.open
  # * https://api.slack.com/types/im
  defp cache_direct_chat(user_id, direct_chat, ttl) do
    expiry = expiration(ttl)
    cache_item = cache_item(direct_chat)
    :ets.insert(@direct_chat_channel_cache, {user_id, {cache_item, expiry}})
    cache_item
  end

  # Create pared-down versions of Slack API objects to serve as values
  # in our caches.
  #
  # We extract only the information we care about, and use atom keys
  # instead of strings.
  defp cache_item(%{"is_channel" => true, "id" => id, "name" => name, "is_member" => is_member}),
    do: %{id: id, name: name, is_member: is_member}
  defp cache_item(%{"is_group" => true, "id" => id, "name" => name}),
    do: %{id: id, name: name}
  # users have names, but not "is_user" fields :( they do have profiles, though
  defp cache_item(%{"id" => id, "name" => name, "profile" => profile}),
  do: %{id: id, handle: name, email: profile["email"], first_name: profile["first_name"],
        last_name: profile["last_name"]}
  # result of 'im.open' calls; they have no name
  defp cache_item(%{"id" => id}=im) when map_size(im) == 1,
    do: %{id: id}

  defp expiration(ttl),
    do: Cog.Time.now + ttl

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

  defp expire_key(key) do
    :ets.delete(@channel_cache, key)
  end

  defp extract_key([id: id]), do: id
  defp extract_key([name: name]), do: name
  defp extract_key([handle: handle]), do: handle

  ########################################################################

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

  # Translate Slack error strings to Elixir atoms
  #
  # im.open can also raise "not_authed", "invalid_auth", and
  # "account_inactive" errors, per the docs
  # (https://api.slack.com/methods/im.open), but there's no way the
  # application would get this far to have those show up here.
  defp translate_slack_error("im.open", "user_not_found"), do: :user_not_found
  defp translate_slack_error("im.open", "user_not_visible"), do: :user_not_visible
  defp translate_slack_error("im.open", "user_disabled"), do: :user_disabled
end
