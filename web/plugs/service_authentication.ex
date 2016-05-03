defmodule Cog.Plug.ServiceAuthentication do
  @behaviour Plug

  import Plug.Conn
  import Cog.Plug.Util, only: [set_service_token: 2]

  alias Cog.Command.Service.Tokens

  def init(opts),
    do: opts

  def call(conn, _opts) do
    case conn |> extract_token do
      token when is_binary(token) ->
        case Tokens.process_for_token(token) do
          process when is_pid(process) ->
            conn
            |> set_service_token(token)
          {:error, :unknown_token} ->
            conn
            |> resp(401, Poison.encode!(%{"error" => "unknown token"}))
            |> halt
        end
      nil ->
        conn
        |> resp(401, "")
        |> halt
    end
  end

  # Extract token from the request headers.
  #
  # The expected header format is:
  #
  #   Authorization: pipeline $TOKEN
  #
  # Returns the token string or `nil` if no value could be obtained.
  defp extract_token(conn) do
    case get_req_header(conn, "authorization") do
      [value] ->
        case String.split(value) do
          ["pipeline", token] -> token
          _ -> nil
        end
      [] -> nil
    end
  end

end
