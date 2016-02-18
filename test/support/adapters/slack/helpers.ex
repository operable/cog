defmodule Cog.Adapters.Slack.Helpers do
  alias Cog.Adapters.Slack
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

  def retrieve_last_message(room: room, oldest: oldest) do
    {:ok, %{id: channel}} = Slack.API.lookup_room(name: room)

    url = "https://slack.com/api/channels.history"
    params = %{channel: channel, oldest: oldest, count: 1, token: token}
    query = URI.encode_query(params)

    response = HTTPotion.get(url <> "?" <> query, headers: ["Accept": "application/json"])
    parse_last_message(Poison.decode!(response.body))
  end

  def send_message(user, message) do
    {:ok, %{id: channel}} = Slack.API.lookup_room(name: @room)

    url = "https://slack.com/api/chat.postMessage"
    params = %{channel: channel, text: message, as_user: user.username, token: token}
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
          [%{"text" => text}] ->
            {:ok, Slack.Formatter.unescape(text)}
        end
    end
  end

  defp token do
    System.get_env("SLACK_USER_API_TOKEN")
  end
end
