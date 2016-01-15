defmodule Cog.Plug.Authentication.Test do
  use Cog.ModelCase
  use Plug.Test
  alias Cog.Plug.Authentication

  import Cog.Plug.Util, only: [get_user: 1,
                               stamp_start_time: 1]

  @default_token_lifetime 42 # seconds, just because

  setup do
    user = user("cog")
    token = Cog.Models.Token.generate
    {:ok, _} = Cog.Models.Token.insert_new(user, %{value: token})
    {:ok, [user: user,
           token: token]}
  end

  test "saves authenticated user in conn", %{user: user, token: token} do
    conn = conn(:get, "/")
    |> stamp_start_time
    |> put_req_header("authorization", "token #{token}")
    |> Authentication.call(@default_token_lifetime)

    refute conn.halted
    refute conn.status
    assert get_user(conn) == user
  end

  test "halts if no authorization header is set" do
    conn = conn(:get, "/")
    |> Authentication.call(@default_token_lifetime)

    assert conn.halted
    assert conn.status == 401 # unauthorized
    refute get_user(conn)
  end

  test "halts if authorization header value is malformed", %{token: token} do
    conn = conn(:get, "/")
    |> put_req_header("authorization", "token----#{token}")
    |> Authentication.call(@default_token_lifetime)

    assert conn.halted
    assert conn.status == 401 # unauthorized
    refute get_user(conn)
  end

  test "halts if token is not found" do
    conn = conn(:get, "/")
    |> put_req_header("authorization", "token #{Cog.Models.Token.generate}")
    |> Authentication.call(@default_token_lifetime)

    assert conn.halted
    assert conn.status == 401 # unauthorized
    refute get_user(conn)
  end

  test "halts if token is older than the configured token time-out", %{token: token} do
    # We're going to set a super-low timeout and then sleep a bit to
    # ensure our token is expired
    ttl_in_seconds = 1
    :timer.sleep ttl_in_seconds * 1000 # milliseconds!

    conn = conn(:get, "/")
    |> put_req_header("authorization", "token #{token}")
    |> Authentication.call(ttl_in_seconds)

    assert conn.halted
    assert conn.status == 401
    refute get_user(conn)
    assert conn.resp_body == Poison.encode!(%{"error" => "token expired"})
  end
end
