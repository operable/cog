defmodule Cog.Adapters.Slack.API do
  require Logger
  use GenServer

  defstruct token: nil, ttl: nil

  @default_ttl 900
  @slack_api "https://slack.com/api/"
  @server_name :slack_api
  @user_cache :slack_api_users
  @room_cache :slack_api_rooms
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
    case query_cache(@room_cache, key) do
      nil ->
        GenServer.call(@server_name, {:lookup_room, key}, :infinity)
      entry ->
        {:ok, entry}
    end
  end

  def lookup_room(id, as_user: as_user) do
    case String.replace(id, ~r/<([^>]*)>/, "\\1") do
      "@" <> user_id ->
        lookup_direct_room(user_id: user_id, as_user: as_user)
      "#" <> room_id ->
        lookup_room(id: room_id)
      other ->
        case GenServer.call(@server_name, {:lookup_room, [name: other]}, :infinity) do
          {:ok, room} ->
            {:ok, room}
          {:error, _} ->
            case GenServer.call(@server_name, {:lookup_user, [handle: other]}, :infinity) do
              {:ok, user} ->
                lookup_direct_room(user_id: user.id, as_user: as_user)
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
        :ets.new(@room_cache, [:named_table, {:read_concurrency, true}])
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
    case call_api!("channels.info", state.token, body: %{channel: id},
                   parser: &parse_channel_result/1) do
      {:ok, room} ->
        expiry = Cog.Time.now() + state.ttl
        :ets.insert(@room_cache, {id, {room, expiry}})
        {:reply, {:ok, room}, state}
      error ->
        {:reply, error, state}
    end
  end
  def handle_call({:lookup_room, [name: name]}, _from, state) do
    case call_api!("channels.list", state.token, parser: &(parse_rooms_result(&1, name, state))) do
      {:ok, room} ->
        {:reply, {:ok, room}, state}
      error ->
        {:reply, error, state}
    end
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
      {:reply, {:error, result["error"]}, state}
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

  defp parse_rooms_result(result, query, state) do
    case result["ok"] do
      false ->
        {:error, result["error"]}
      true ->
        expiry = Cog.Time.now() + state.ttl
        case Enum.reduce(result["channels"], nil,
              fn(room, acc) ->
                room_record = %{id: room["id"],
                                name: room["name"],
                                topic: room["topic"]}
                :ets.insert(@room_cache, {room["id"], {room_record, expiry}})
                :ets.insert(@room_cache, {room["name"], {room["id"], expiry}})
                maybe_return_room(query, room_record, acc) end) do
          nil ->
            {:error, :not_found}
          value ->
            {:ok, value}
        end
    end
  end

  defp maybe_return_room(query, %{name: query}=room, nil), do: room
  defp maybe_return_room(_query, _room, acc), do: acc

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

  defp parse_channel_result(result) do
    case result["ok"] do
      false ->
        {:error, result["error"]}
      true ->
        {:ok, %{id: result["channel"]["id"],
                name: result["channel"]["name"],
                topic: result["channel"]["topic"]}}
    end
  end

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

end
