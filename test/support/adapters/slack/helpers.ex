defmodule Cog.Adapters.Slack.Helpers do
  alias Cog.Assertions

  require Logger
  @bot_handle "deckard"
  @room "#ci_bot_testing"
  @interval 1000 # 1 second
  @timeout 120000 # 2 minutes

  # keyword args:
  #   after: the last Slack message sent; you only want to look at
  #          responses that came in after this one. Required argument.
  #   count: the number of messages you want to retrieve and assert
  #          against. Optional, defaulting to 1
  def assert_response(message, opts, room \\ @room) do

    %{"ts" => ts} = Keyword.fetch!(opts, :after)
    expected_count = Keyword.get(opts, :count, 1)

    :timer.sleep(@interval)

    last_message_func = fn ->
      {:ok, last_message} = retrieve_last_message(room: room, oldest: ts, count: expected_count)
      last_message
    end

    Assertions.polling_assert(message, last_message_func, @interval, @timeout)
  end

  # keyword args:
  #   after: the last Slack message sent; you only want to look at
  #          responses that came in after this one. Required argument.
  #   count: the number of messages you want to retrieve and assert
  #          against. Optional, defaulting to 1
  def assert_response_contains(message, opts, room \\ @room) do
    %{"ts" => ts} = Keyword.fetch!(opts, :after)
    expected_count = Keyword.get(opts, :count, 1)

    :timer.sleep(@interval)

    last_message_func = fn ->
      {:ok, last_message} = retrieve_last_message(room: room, oldest: ts, count: expected_count)
      last_message
    end

    Assertions.polling_assert_in(message, last_message_func, @interval, @timeout)
  end

  def assert_edited_response(message, opts),
    do: assert_response(message, Keyword.put(opts, :count, 2))

  def retrieve_last_message(room: room, oldest: oldest),
    do: retrieve_last_message(room: room, oldest: oldest, count: 1)
  def retrieve_last_message(room: room, oldest: oldest, count: count) do
    {:ok, %{id: channel}} = Cog.Chat.Adapter.lookup_room("slack", name: room)

    url = case channel do
      "C" <> _ ->
        "https://slack.com/api/channels.history"
      "G" <> _ ->
        "https://slack.com/api/groups.history"
    end

    params = %{channel: channel, oldest: oldest, count: count, token: token}
    query = URI.encode_query(params)

    response = HTTPotion.get(url <> "?" <> query, headers: ["Accept": "application/json"])
    maybe_consume_messages(Poison.decode!(response.body), count)
  end

  def send_message(message, room \\ @room) do
    {:ok, %{id: channel}} = Cog.Chat.Adapter.lookup_room("slack", name: room)

    url = "https://slack.com/api/chat.postMessage"
    params = %{channel: channel, text: message, as_user: true,
               token: token, parse: "full"}

    query = URI.encode_query(params)
    response = HTTPotion.get(url <> "?" <> query, headers: ["Accept": "application/json"])
    {:ok, message} = parse_message(Poison.decode!(response.body))
    message
  end

  def send_edited_message(message, initial_message \\ "FOO3rjha92") do
    {:ok, %{id: channel}} = Cog.Chat.Adapter.lookup_room("slack", name: @room)
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

  # If the response contains at least `expected_count` messages,
  # process the first `expected_count` of them and return.
  #
  # Otherwise, we are still waiting for Slack to get some
  # messages.
  defp maybe_consume_messages(result, expected_count) do
    case result["ok"] do
      false ->
        {:error, result["error"]}
      true ->
        messages = result["messages"]
        if length(messages) < expected_count do
          # we haven't gotten everything we expect. Return nil;
          # we'll try and get the rest of the messages next time
          {:ok, nil}
        else
          # We've gotten at least as many messages as we asked
          # for; we'll take just as many as we expected to get
          formatted = Enum.sort(messages, &(&1["ts"] < &2["ts"]))
          |> Enum.take(expected_count)
          |> Enum.map(&extract_message/1)
          |> Enum.join("\n")
          {:ok, formatted}
        end
    end
  end

  # So, this is the token of the USER that we're interacting with the
  # bot as
  defp token do
    System.get_env("SLACK_USER_API_TOKEN")
  end

  defp extract_message(%{"attachments" => [%{"text" => message}]})
  when is_binary(message) and message != "",
    do: message
  defp extract_message(%{"attachments" => attachments}=message)
  when attachments != [] do
    Logger.warn("""

    Received a message with more than one attachment, or one
    attachment with an empty "text" field. This testing infrastructure
    currently assumes at most one attachment, with a non-empty "text"
    field.

    If you see this message, this assumption has been violated.

    Message:
    #{inspect message, pretty: true}

    """)
    raise "bad attachment"
  end
  defp extract_message(%{"text" => message}) when is_binary(message),
    do: message

end
