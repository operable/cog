defmodule Cog.V1.TokenControllerTest do
  use Cog.ConnCase
  use Cog.ModelCase

  alias Cog.Models.Token

  setup do
    conn = conn() |> put_req_header("accept", "application/json")
    {:ok, conn: conn}
  end

  test "creates and renders resource when data is valid", %{conn: conn} do
    user("tester")
    conn = post(conn, "/v1/token",
                %{"username" => "tester", "password" => "tester"})

    token_value = json_response(conn, 201)["token"]["value"]
    assert Repo.get_by(Token, value: token_value)
  end

  test "does not create resource and renders errors when username is invalid", %{conn: conn} do
    user("tester")
    conn = post(conn, "/v1/token",
                %{"username" => "not_tester", "password" => "tester"})
    assert json_response(conn, 403)["errors"] != %{}
  end

  test "does not create resource and renders errors when password is invalid", %{conn: conn} do
    user("tester")
    conn = post(conn, "/v1/token",
                %{"username" => "tester", "password" => "wrong_password"})
    assert json_response(conn, 403)["errors"] != %{}
  end

end
