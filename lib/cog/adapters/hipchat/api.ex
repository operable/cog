defmodule Cog.Adapters.HipChat.API do
  use GenServer
  alias Cog.Adapters.HipChat

  @base_uri "https://api.hipchat.com/v2"
  @timeout 15000 # 15 seconds

  def start_link(config) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  def send_message(room, message) do
    GenServer.call(__MODULE__, {:send_message, room, message})
  end

  def lookup_room("@" <> handle) do
    user = lookup_user(name: "@" <> handle)
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
    case lookup_room(name: room_name) do
      {:ok, room} ->
        users = lookup_users()
        user = Enum.find(users, &match?(%{"name" => ^user_name}, &1))
        {:ok, %{room: room, user: user}}
      {:error, error} ->
        {:error, error}
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

  # TODO: Check that token is valid before  returning successfully
  def init(config) do
    token = config[:api][:token]
    {:ok, %{client: %{token: token}}}
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
    result = get(state.client, uri)
    {:reply, result, state}
  end

  def handle_call({:lookup_user, id: user_id}, _from, state) do
    uri = "/user/#{user_id}"
    result = get(state.client, uri)
    {:reply, result, state}
  end

  def handle_call(:lookup_users, _from, state) do
    uri = "/user"
    result = get(state.client, uri)
    {:reply, result, state}
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
    body = Poison.decode!(response.body)

    case HTTPotion.Response.success?(response) do
      true ->
        {:ok, body}
      false ->
        {:error, body["error"]}
    end
  end

  def include_headers(options, config) do
    headers = request_headers(config)
    Keyword.update(options, :headers, headers, &(headers ++ &1))
  end

  def request_headers(%{token: token}) do
    ["Accept":        "application/json",
     "Content-Type":  "application/json",
     "Authorization": "Bearer #{token}"]
  end

  def encode_body(options) do
    case Keyword.has_key?(options, :body) do
      true ->
        Keyword.update!(options, :body, &Poison.encode!/1)
      false ->
        options
    end
  end
end
