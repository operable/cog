defmodule Cog.Adapters.HipChat.API do
  alias Cog.Adapters.HipChat
  require Logger

  use HTTPoison.Base

  defstruct token: nil

  @api_base "https://api.hipchat.com/v2"
  @timeout 15000 # 15 seconds

  def send_message(%{"id" => room_id}, message) do
    url = "/room/#{room_id}/message"
    body = Poison.encode!(%{message: message})
    {:ok, response} = post(url, body)
    response.body
  end
  def send_message(%{"direct" => user_id}, message) do
    url = "/user/#{user_id}/message"
    body = Poison.encode!(%{message: message})
    {:ok, response} = post(url, body)
    response.body
  end

  def lookup(subject, id, expands \\ nil) do
    get!("/#{subject}/#{id}" <> expands_list(expands))
  end

  def lookup_direct_room(user_id: user_id),
    do: {:ok, %{"direct" => user_id}}

  defp expands_list(nil), do: ""
  defp expands_list(expands) do
    "?expand=" <> Enum.join(expands, ",")
  end

  # TODO: cache looking up the users in the room
  def lookup_room_user(room_name, user_name) do
    room = lookup("room", room_name).body
    members = get!("/user").body["items"]

    user = Enum.find(members, fn(user) ->
      Map.get(user, "name") == user_name
    end)

    %{room: normalize_room(room),
      user: normalize_user(user)}
  end

  def lookup_user(opts) do
    lookup("user", option_key(opts))
    |> Map.get(:body)
    |> normalize_user
  end

  def lookup_room("@" <> handle, as_user: _) do
    user = lookup_user(name: "@" <> handle)
    lookup_direct_room(user_id: user.id)
  end
  def lookup_room("#" <> room, as_user: _) do
    room = lookup_room(name: room)
    {:ok, room}
  end
  def lookup_room(id, as_user: _) do
    case lookup_user(name: "@" <> id) do
      %{id: nil} ->
        case lookup_room(lookup_room(name: id)) do
          room ->
            {:ok, room}
        end
      user ->
        lookup_direct_room(user_id: user.id)
    end
  end

  def lookup_room(opts) do
    lookup("room", option_key(opts))
    |> Map.get(:body)
    |> normalize_room
  end

  def retrieve_last_message(room_name, not_before) do
    room = lookup_room(name: room_name)

    url = "/room/#{room.id}/history/latest"
    query = URI.encode_query("max-results": 2, "not-before": not_before)

    get!(url <> "?" <> query)
    |> Map.get(:body)
    |> normalize_last_message
  end

  defp option_key(opts), do: opts[:id] || opts[:handle] || opts[:name]

  defp normalize_user(user)  do
    %{id: user["id"],
      handle: user["mention_name"]}
  end

  defp normalize_room(room) do
    %{id: room["id"],
      name: room["name"]}
  end

  defp normalize_last_message(%{"items" => [_sent_message, item|_]}),
    do: item["message"]
  defp normalize_last_message(%{"items" => _}),
    do: nil

  def request(method, url, body, headers, options) do
    default_options = [timeout: @timeout]
    options = options ++ default_options
    super(method, url, body, headers, options)
  end

  def process_url(url) do
    @api_base <> url
  end

  def process_request(body) do
    Poison.decode!(body)
  end

  def process_request_headers(headers) do
    [{"Content-Type", "application/json"},
     {"Authorization", "Bearer " <> api_token}|headers]
  end

  def process_response_body(body) do
    case body do
      "" ->
        ""
      body ->
        Poison.decode!(body)
    end
  end

  def process_headers(headers) do
    ratelimit = Enum.into(headers, %{})
    |> Map.get("X-Ratelimit-Remaining")

    if ratelimit == "0" do
      Logger.error("HipChat ratelimit exceeded")
    end

    headers
  end

  defp api_token do
    config = HipChat.Config.fetch_config!
    config[:api][:token]
  end
end
