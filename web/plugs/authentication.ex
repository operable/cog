defmodule Cog.Plug.Authentication do
  @behaviour Plug

  import Plug.Conn
  import Cog.Plug.Util, only: [set_user: 2]

  alias Cog.Models.User
  alias Cog.Repo
  alias Cog.Config
  alias Cog.Events.ApiEvent

  def init(_opts),
    do: Config.token_lifetime

  def call(conn, ttl_in_seconds) do
    case conn |> extract_token |> user_from_token(ttl_in_seconds) do
      %User{}=user ->
        conn
        |> set_user(user)
        |> authenticated_event
      :expired_token ->
        conn
        |> resp(401, Poison.encode!(%{"error" => "token expired"}))
        |> halt
      nil ->
        conn
        |> resp(401, "")
        |> halt
    end
  end

  # Extract token from the request headers.
  #
  # We're copying Github's approach for now, expecting a header of the
  # form:
  #
  #   Authorization: token $TOKEN
  #
  # Returns the token string (NOT a `Cog.Models.Token` struct!), or
  # `nil` if no value could be obtained.
  defp extract_token(conn) do
    case get_req_header(conn, "authorization") do
      [value] ->
        case String.split(value) do
          ["token", token] -> token
          _ -> nil
        end
      [] -> nil
    end
  end

  # Retrieve a User struct given a `token`.  If the token is valid, we
  # return the User. If the token has expired, return
  # `:expired_token`. If the token was not found at all, return `nil`.
  defp user_from_token(nil, _),
    do: nil
  defp user_from_token(token, ttl_in_seconds) do
    case Repo.one(Cog.Queries.User.for_token(token, ttl_in_seconds)) do
      {user, true} -> user
      {%User{}, false} -> :expired_token
      nil -> nil
    end
  end

  # Emit an authenticated event. Returns `conn` for pipelines
  defp authenticated_event(conn) do
    conn |> ApiEvent.authenticated |> Probe.notify
    conn
  end

end
