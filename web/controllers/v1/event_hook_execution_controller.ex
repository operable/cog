defmodule Cog.V1.EventHookExecutionController do
  use Cog.Web, :controller

  import Cog.Plug.Util, only: [get_request_id: 1,
                               get_user: 1,
                               set_user: 2]

  require Logger

  alias Cog.Plug.Authentication

  alias Cog.Models.User
  alias Cog.Models.EventHook
  alias Cog.Repository.EventHooks
  alias Cog.Adapters.Http.AdapterBridge

  def execute_hook(conn, %{"id" => hook_id}) do
    case EventHooks.hook_definition(hook_id) do
      {:ok, %EventHook{active: true}=hook} ->
        conn = resolve_user(conn, hook)
        case get_user(conn) do
          %User{username: as_user} ->

            request_id = get_request_id(conn)
            timeout    = hook.timeout_sec * 1000

            context = %{hook_id: hook_id,
                        headers: headers_to_map(conn.req_headers),
                        query_params: conn.query_params,
                        body: conn.body_params}

            requestor = requestor_map(hook_id, as_user, hook.name)

            case AdapterBridge.submit_request(requestor, request_id, context, hook.pipeline, timeout) do
              %{"status" => "ok"} ->
                conn |> send_resp(:no_content, "")
              {:error, :timeout} ->
                conn
                |> put_status(:accepted)
                |> json(%{status: "Request accepted and still processing after #{hook.timeout_sec} seconds",
                          id: request_id})
              response ->
                # TODO: FIIIIIIIIILTHY HACK
                # Until we have proper error templates, the easiest
                # way to distinguish errors from success is to see if
                # the response "looks like an error".
                if is_binary(response) && String.contains?(response, "An error has occurred") do
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
      {:ok, %EventHook{active: false}} ->
        conn |> put_status(:unprocessable_entity) |> json(%{errors: "Hook is not active"})
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{errors: "Hook not found"})
      {:error, :bad_id} ->
        conn
        |> put_status(:bad_request)
        |> json(%{errors: "Bad ID format"})
    end
  end

  ########################################################################

  # This is the requestor map that will eventually make its way into
  # the executor and subsequently to commands. It's how we'll expose
  # hook metadata to commands, for instance.
  defp requestor_map(hook_id, hook_user, hook_name) do
    %{id: hook_user,
      hook_user: hook_user,
      hook_id: hook_id,
      hook_name: hook_name}
  end

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

  # If a hook specifies a user, we use that. If it doesn't, we require
  # an authentication token; the hook will execute as that user that
  # ownd the token
  defp resolve_user(conn, hook) do
    case hook.as_user do
      username when is_binary(username)->
        case Cog.Repo.get_by(User, username: username) do
          %User{}=user ->
            set_user(conn, user)
          nil ->
            conn |> put_status(:unprocessable_entity) |> json(%{errors: "Configured hook user does not exist"})
        end
      nil ->
        Authentication.call(conn, Authentication.init(:argument_ignored))
    end
  end

end
