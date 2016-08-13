defmodule Cog.Adapters.Slack.Helpers do
  alias Cog.Assertions

  @bot_handle "deckard"
  @room "ci_bot_testing"
  @interval 1000 # 1 second
  @timeout 120000 # 2 minutes

  def assert_response(message, [after: %{"ts" => ts}]) do
    :timer.sleep(@interval)

    last_message_func = fn ->
      {:ok, last_message} = retrieve_last_message(room: @room, oldest: ts)
      last_message
    end

    Assertions.polling_assert(message, last_message_func, @interval, @timeout)
  end

  def assert_response_contains(message, [after: %{"ts" => ts}]) do
    :timer.sleep(@interval)

    last_message_func = fn ->
      {:ok, last_message} = retrieve_last_message(room: @room, oldest: ts)
      last_message
    end

    Assertions.polling_assert_in(message, last_message_func, @interval, @timeout)
  end

  def assert_edited_response(message, [after: %{"ts" => ts}]) do
    :timer.sleep(@interval)

    last_message_func = fn ->
      {:ok, last_message} = retrieve_last_message(room: @room, oldest: ts, count: 2)
      last_message
    end

    Assertions.polling_assert(message, last_message_func, @interval, @timeout)
  end

  def retrieve_last_message(room: room, oldest: oldest),
    do: retrieve_last_message(room: room, oldest: oldest, count: 1)
  def retrieve_last_message(room: room, oldest: oldest, count: count) do
    {:ok, %{id: channel}} = Cog.Chat.Adapter.lookup_room("slack", room)

    url = "https://slack.com/api/channels.history"
    params = %{channel: channel, oldest: oldest, count: count, token: token}
    query = URI.encode_query(params)

    response = HTTPotion.get(url <> "?" <> query, headers: ["Accept": "application/json"])
    parse_last_message(Poison.decode!(response.body))
  end

  def send_message(message) do
    {:ok, %{id: channel}} = Cog.Chat.Adapter.lookup_room("slack", @room)

    url = "https://slack.com/api/chat.postMessage"
    params = %{channel: channel, text: message, as_user: true,
               token: token, parse: "full"}

    query = URI.encode_query(params)
    response = HTTPotion.get(url <> "?" <> query, headers: ["Accept": "application/json"])
    {:ok, message} = parse_message(Poison.decode!(response.body))
    message
  end



  def send_edited_message(message, initial_message \\ "FOO3rjha92") do
    {:ok, %{id: channel}} = Cog.Chat.Adapter.lookup_room("slack", @room)
    initial_response = send_message(initial_message)
    url = "https://slack.com/api/chat.update"
    params = %{channel: channel, ts: initial_response["ts"], text: message, parse: "full", as_user: true, token: token}
    query = URI.encode_query(params)

    response = HTTPotion.get(url <> "?" <> query, headers: ["Accept": "application/json"])

    {:ok, message} = parse_message(Poison.decode!(response.body))
    message
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
          messages ->
            formatted = Enum.sort(messages, &(&1["ts"] < &2["ts"]))
            |> Enum.map_join("\n", &(&1["text"]))

            {:ok, formatted}
        end
    end
  end

  # So, this is the token of the USER that we're interacting with the
  # bot as
  defp token do
    System.get_env("SLACK_USER_API_TOKEN")
  end
end
