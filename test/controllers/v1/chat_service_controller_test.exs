defmodule Cog.V1.ChatServiceControllerTest do
  use Cog.ConnCase

  @moduletag :services
  @endpoint Cog.ServiceEndpoint

  @path "/v1/services/chat/1.0.0"

  alias Cog.Command.Service.Tokens

  setup do
    # This makes the test process look like a pipeline executor,
    # because the token will be registered to it.
    token = Tokens.new
    conn = tokened_connection(token)
    {:ok, [conn: conn]}
  end

  defp tokened_connection(token) do
    build_conn()
    |> Plug.Conn.put_req_header("content-type", "application/json")
    |> Plug.Conn.put_req_header("authorization", "pipeline #{token}")
  end

  test "requests without a token are denied" do
    conn = post(build_conn(), @path <> "/send_message")
    assert response(conn, 401)
  end

  test "sending message to an unknown user is an error", %{conn: conn} do
    conn = post(conn, @path <> "/send_message", Poison.encode!(%{destination: "@fake_user", message: "taco"}))
    assert %{"error" => "Unable to find chat user for @fake_user"} == json_response(conn, 404)
  end

  test "sending message to an unknown room is an error", %{conn: conn} do
    conn = post(conn, @path <> "/send_message", Poison.encode!(%{destination: "#fake_room", message: "taco"}))
    assert %{"error" => "Unable to find chat room for #fake_room"} == json_response(conn, 404)
  end

  test "sending message to an invalid destination is an error", %{conn: conn} do
    conn = post(conn, @path <> "/send_message", Poison.encode!(%{destination: "definitely_fake", message: "taco"}))
    assert %{"error" => "Invalid chat destination URI definitely_fake"} == json_response(conn, 404)
  end

  test "sending message to a good message results in a success", %{conn: conn} do
    conn = post(conn, @path <> "/send_message", Poison.encode!(%{destination: "#ci_bot_testing", message: "taco"}))
    assert %{"status" => "sent"} == json_response(conn, 200)
  end

end
