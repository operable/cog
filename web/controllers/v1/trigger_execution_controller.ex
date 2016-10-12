defmodule Cog.V1.TriggerExecutionController do
  use Cog.Web, :controller

  import Cog.Plug.Util, only: [get_request_id: 1,
                               get_user: 1,
                               set_user: 2]

  require Logger

  alias Cog.Plug.Authentication

  alias Cog.Models.User
  alias Cog.Models.Trigger
  alias Cog.Repository.Triggers
  alias Cog.Chat.Http.Connector

  plug :parse

  def execute_trigger(conn, %{"id" => trigger_id}) do
    case Triggers.trigger_definition(trigger_id) do
      {:ok, %Trigger{enabled: true}=trigger} ->
        conn = resolve_user(conn, trigger)
        case get_user(conn) do
          %User{}=user ->

            conn = Plug.Conn.fetch_query_params(conn)
            request_id = get_request_id(conn)
            timeout    = computed_timeout(trigger)

            context = %{trigger_id: trigger_id,
                        headers: headers_to_map(conn.req_headers),
                        query_params: conn.query_params,
                        raw_body: get_raw_body(conn),
                        body: get_parsed_body(conn)}

            requestor = to_chat_user(user)

            case Connector.submit_request(requestor, request_id, context, trigger.pipeline, timeout) do
              "ok" ->
                conn |> send_resp(:no_content, "")
              {:error, :timeout} ->
                conn
                |> put_status(:accepted)
                |> json(%{status: "Request accepted and still processing after #{trigger.timeout_sec} seconds",
                          id: request_id})
              response ->
                if is_map(response) and Map.has_key?(response, "error_message") do
                  conn |> put_status(:internal_server_error) |> json(%{errors: response})
                else
                  conn |> put_status(:ok) |> json(response)
                end
            end
          nil ->
            # Don't know which user to run this as, but the response
            # will have already been set, so pass it on out. See
            # resolve_user/2 below
            conn
        end
      {:ok, %Trigger{enabled: false}} ->
        conn |> put_status(:unprocessable_entity) |> json(%{errors: "Trigger is not enabled"})
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{errors: "Trigger not found"})
      {:error, :bad_id} ->
        conn
        |> put_status(:bad_request)
        |> json(%{errors: "Bad ID format"})
    end
  end

  ########################################################################

  # Convert a header list into a map, accumulating multiple values
  # into lists. Single values remain as single values.
  defp headers_to_map(headers) do
    Enum.reduce(headers, %{}, fn({k,v}, acc) ->
      case Map.fetch(acc, k) do
        :error ->
          Map.put(acc, k, v)
        multiple when is_list(multiple) ->
          Map.put(acc, k, Enum.concat(multiple,[v]))
        single ->
          Map.put(acc, k, [single, v])
      end
    end)
  end

  # If a trigger specifies a user, we use that. If it doesn't, we require
  # an authentication token; the trigger will execute as that user that
  # ownd the token
  defp resolve_user(conn, trigger) do
    case trigger.as_user do
      username when is_binary(username)->
        case Cog.Repo.get_by(User, username: username) do
          %User{}=user ->
            set_user(conn, user)
          nil ->
            conn |> put_status(:unprocessable_entity) |> json(%{errors: "Configured trigger user does not exist"})
        end
      nil ->
        Authentication.call(conn, Authentication.init(:argument_ignored))
    end
  end

  # In order to preserve the ability for pipelines to perform request
  # verification, we need to keep both the raw body (which is usually
  # what is cryptographically hashed with a user-provided secret) as
  # well as the JSON-parsed body (to allow easy variable binding in
  # pipelines, and not require manual JSON parsing).
  #
  # Unfortunately, that means we need to do the parsing ourselves
  # instead of relying on Phoenix's Plug.Parsers.JSON, which consumes
  # the raw body and doesn't make it available afterward.
  #
  # See https://hexdocs.pm/plug/1.1.3/Plug.Conn.html#read_body/2 for
  # details.
  defp parse(conn, []) do
    {:ok, raw_body, conn} = read_body(conn)
    parsed_body = case raw_body do
                    "" ->
                      {:ok, %{}}
                    _ ->
                      case get_content_type(conn) do
                        :undefined ->
                          {:error, "missing content-type"}
                        type ->
                          parse_type(type, raw_body)
                      end
                  end

    case parsed_body do
      {:ok, parsed} ->
        conn
        |> set_raw_body(raw_body)
        |> set_parsed_body(parsed)
      {:error, _} ->
        conn
        |> put_status(:unsupported_media_type)
        |> halt
    end
  end

  defp parse_type("application/x-www-form-urlencoded", body) do
    Plug.Conn.Utils.validate_utf8!(body, Plug.Parsers.BadEncodingError, "urlencoded body")
    {:ok, Plug.Conn.Query.decode(body)}
  end

  defp parse_type("application/json", body) do
    Poison.decode(body)
  end

  defp parse_type(type, _body) do
    {:error, "invalid trigger content-type: #{type}"}
  end

  defp set_raw_body(conn, raw_body),
    do: assign(conn, :raw_body, raw_body)

  defp get_raw_body(conn),
    do: conn.assigns[:raw_body]

  defp set_parsed_body(conn, parsed_body),
    do: assign(conn, :parsed_body, parsed_body)

  defp get_parsed_body(conn),
    do: conn.assigns[:parsed_body]

  defp get_content_type(conn) do
    agent = :proplists.get_value("user-agent", conn.req_headers)
    maybe_override_type(agent, conn)
  end

  # This is a dirty hack to special case inbound requests from Amazon SNS
  # to trigger endpoints. SNS appears to send `text/plain` as the Content-Type
  # for its requests, despite sending a JSON payload. If this becomes a more
  # common problem we may look at other more generalized options for this,
  # but for now we'll start with a simple override for SNS specifically.
  defp maybe_override_type("Amazon Simple Notification Service Agent", _),
   do: "application/json"

  defp maybe_override_type(_, conn),
   do: :proplists.get_value("content-type", conn.req_headers)

  ########################################################################

  defp computed_timeout(%Trigger{timeout_sec: timeout_sec}) do
    case Application.get_env(:cog, :trigger_timeout_buffer) do
      slack when slack <= timeout_sec ->
        (timeout_sec - slack) * 1000
      _ ->
        0
    end
  end

  defp to_chat_user(%Cog.Models.User{username: username,
                                     first_name: first_name,
                                     last_name: last_name}) do
    %Cog.Chat.User{id: username,
                   first_name: first_name,
                   last_name: last_name,
                   provider: "http",
                   handle: username}
  end

end
