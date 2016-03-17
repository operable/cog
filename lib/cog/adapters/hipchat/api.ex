defmodule Cog.Adapters.HipChat.API do
  use GenServer
  require Logger

  @base_uri "https://api.hipchat.com/v2"
  @timeout 15000 # 15 seconds

  def start_link(config) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  def send_message(room, message) do
    GenServer.call(__MODULE__, {:send_message, room, message})
  end

  def lookup_room("@" <> handle) do
    {:ok, user} = lookup_user(name: "@" <> handle)
    lookup_direct_room(user_id: user.id)
  end

  def lookup_room("#" <> room) do
    lookup_room(name: room)
  end

  def lookup_room(options) do
    GenServer.call(__MODULE__, {:lookup_room, options})
  end

  def lookup_direct_room(user_id: user_id) do
    {:ok, %{"direct" => user_id}}
  end

  def lookup_room_user(room_name, user_name) do
    with {:ok, room} <- lookup_room(name: room_name),
         {:ok, users} <- lookup_users() do
      user = Enum.find(users, &match?(%{name: ^user_name}, &1))
      {:ok, %{room: room, user: user}}
    end
  end

  def lookup_user(id: user_id) do
    GenServer.call(__MODULE__, {:lookup_user, id: user_id})
  end

  def lookup_user(name: username) do
    GenServer.call(__MODULE__, {:lookup_user, id: username})
  end

  def lookup_users() do
    GenServer.call(__MODULE__, :lookup_users)
  end

  def retrieve_last_message(room_name, not_before) do
    {:ok, room} = lookup_room(name: room_name)
    GenServer.call(__MODULE__, {:retrieve_last_message, room, not_before})
  end

  def init(config) do
    token = config[:api][:token]
    client = %{token: token}

    case authenticate(client) do
      :ok ->
        {:ok, %{client: client}}
      {:error, :unauthorized} ->
        raise "Authentication with the HipChat API failed. Please check your api token and try again."
      {:error, :nxdomain} ->
        raise "Connecting to the HipChat API failed. Please check your network settings and try again."
    end
  end

  def handle_call({:send_message, %{"id" => room_id}, message}, _from, state) do
    uri = "/room/#{room_id}/message"
    body = %{message: message}
    result = post(state.client, uri, body: body)
    {:reply, result, state}
  end

  def handle_call({:send_message, %{"direct" => user_id}, message}, _from, state) do
    uri = "/user/#{user_id}/message"
    body = %{message: message}
    result = post(state.client, uri, body: body)
    {:reply, result, state}
  end

  def handle_call({:lookup_room, name: room_name}, _from, state) do
    uri = "/room/#{room_name}"

    result = with {:ok, room} <- get(state.client, uri) do
      {:ok, normalize_room(room)}
    end

    {:reply, result, state}
  end

  def handle_call({:lookup_user, id: user_id}, _from, state) do
    uri = "/user/#{user_id}"
    result = get(state.client, uri)

    result = with {:ok, user} <- result do
      {:ok, normalize_user(user)}
    end

    {:reply, result, state}
  end

  def handle_call(:lookup_users, _from, state) do
    uri = "/user"
    result = get(state.client, uri)

    result = with {:ok, %{"items" => users}} <- result do
      {:ok, Enum.map(users, &normalize_user/1)}
    end

    {:reply, result, state}
  end

  def handle_call({:retrieve_last_message, %{id: room_id}, not_before}, _from, state) do
    path = "/room/#{room_id}/history/latest"
    query = URI.encode_query("max-results": 2, "not-before": not_before)
    uri = path <> "?" <> query
    result = get(state.client, uri)

    result = with {:ok, %{"items" => [_sent_message, message|_]}} <- result do
      {:ok, normalize_message(message)}
    end

    {:reply, result, state}
  end

  defp authenticate(client) do
    uri = "/room"

    result = rescue_econnrefused(fn ->
      get(client, uri)
    end)

    case result do
      {:ok, _result} ->
        :ok
      {:error, %{"type" => "Unauthorized"}} ->
        {:error, :unauthorized}
      {:error, error} ->
        {:error, error}
    end
  end

  defp get(client, uri, options \\ []) do
    request(client, :get, uri, options)
  end

  defp post(client, uri, options) do
    request(client, :post, uri, options)
  end

  defp request(client, method, uri, options) do
    uri = @base_uri <> uri

    options = options
    |> include_headers(client)
    |> encode_body

    response = HTTPotion.request(method, uri, options)

    body = case response.body do
      "" ->
        nil
      _ ->
        Poison.decode!(response.body)
    end

    case HTTPotion.Response.success?(response) do
      true ->
        {:ok, body}
      false ->
        {:error, body["error"]}
    end
  end

  defp include_headers(options, config) do
    headers = request_headers(config)
    Keyword.update(options, :headers, headers, &(headers ++ &1))
  end

  defp request_headers(%{token: token}) do
    ["Accept":        "application/json",
     "Content-Type":  "application/json",
     "Authorization": "Bearer #{token}"]
  end

  defp encode_body(options) do
    case Keyword.has_key?(options, :body) do
      true ->
        Keyword.update!(options, :body, &Poison.encode!/1)
      false ->
        options
    end
  end

  defp normalize_user(%{"id" => id, "mention_name" => handle, "name" => name}) do
    %{id: id, handle: handle, name: name}
  end

  defp normalize_room(%{"id" => id, "name" => name}) do
    %{id: id, name: name}
  end

  defp normalize_message(%{"message" => message}) do
    message
  end

  defp rescue_econnrefused(fun) do
    try do
      fun.()
    rescue
      e in HTTPotion.HTTPError ->
        case e do
          %{message: "nxdomain"} ->
            {:error, :nxdomain}
          _ ->
            {:error, e}
        end
    end
  end
end
