defmodule Cog.V1.MemoryServiceControllerTest do
  use Cog.ConnCase

  @moduletag :services
  @endpoint Cog.ServiceEndpoint

  @path "/v1/services/memory/1.0.0"

  alias Cog.Command.Service.Tokens

  setup do
    # This makes the test process look like a pipeline executor,
    # because the token will be registered to it.
    token = Tokens.new
    conn = tokened_connection(token)
    {:ok, [conn: conn]}
  end

  defp tokened_connection(token) do
    conn()
    |> Plug.Conn.put_req_header("content-type", "application/json")
    |> Plug.Conn.put_req_header("authorization", "pipeline #{token}")
  end

  test "requests without a token are denied" do
    conn = get(conn(), @path <> "/food")
    assert response(conn, 401)
  end

  test "showing a key that doesn't yet exist is a 404", %{conn: conn} do
    conn = get(conn, @path <> "/food")
    assert %{"error" => "key not found"} == json_response(conn, 404)
  end

  test "accum works", %{conn: original_conn} do
    conn = post(original_conn, @path <> "/food", Poison.encode!(%{op: "accum", value: "taco"}))
    assert ["taco"] == json_response(conn, 200)

    conn = post(original_conn, @path <> "/food", Poison.encode!(%{op: "accum", value: "burrito"}))
    assert ["taco", "burrito"] == json_response(conn, 200)

    conn = post(original_conn, @path <> "/food", Poison.encode!(%{op: "accum", value: "churro"}))
    assert ["taco", "burrito", "churro"] == json_response(conn, 200)

    conn = get(original_conn, @path <> "/food")
    assert ["taco", "burrito", "churro"] == json_response(conn, 200)
  end

  test "join works", %{conn: original_conn} do
    conn = put(original_conn, @path <> "/food", Poison.encode!(["taco", "burrito", "churro"]))
    assert ["taco", "burrito", "churro"] == json_response(conn, 200)

    conn = post(original_conn, @path <> "/food", Poison.encode!(%{op: "join", value: ["spaghetti", "lasagna"]}))
    assert ["taco", "burrito", "churro", "spaghetti", "lasagna"] == json_response(conn, 200)
  end

  test "replace works", %{conn: original_conn} do
    conn = post(original_conn, @path <> "/drink", Poison.encode!(%{op: "accum", value: "water"}))
    assert ["water"] == json_response(conn, 200)

    conn = put(original_conn, @path <> "/drink", Poison.encode!(["bulleit", "pappy", "larceny"]))
    assert ["bulleit", "pappy", "larceny"] == json_response(conn, 200)

    conn = get(original_conn, @path <> "/drink")
    assert ["bulleit", "pappy", "larceny"] == json_response(conn, 200)
  end

  test "replacing something that didn't exist first", %{conn: original_conn} do
    conn = put(original_conn, @path <> "/drink", Poison.encode!("water"))
    assert "water" = json_response(conn, 200)
  end

  test "replace works with objects", %{conn: original_conn} do
    conn = put(original_conn, @path <> "/stuff", Poison.encode!(%{whee: "so fun"}))
    assert %{"whee" => "so fun"} == json_response(conn, 200)
  end

  test "deletion works", %{conn: original_conn} do
    conn = post(original_conn, @path <> "/drink", Poison.encode!(%{op: "accum", value: "water"}))
    assert ["water"] == json_response(conn, 200)

    # delete returns the deleted value
    conn = delete(original_conn, @path <> "/drink")
    assert ["water"] == json_response(conn, 200)

    conn = get(original_conn, @path <> "/drink")
    assert response(conn, 404)
  end

  test "values are distinct w/r/t token", %{conn: original_test_conn} do
    conn = post(original_test_conn, @path <> "/drink", Poison.encode!(%{op: "accum", value: "water"}))
    assert ["water"] == json_response(conn, 200)

    # Create another process / token / conn to use for a request
    {_pid, token} = Cog.ServiceHelpers.spawn_fake_executor
    other_conn = tokened_connection(token)
    conn = post(other_conn, @path <> "/drink", Poison.encode!(%{op: "accum", value: "coffee"}))
    assert ["coffee"] == json_response(conn, 200)
  end

  test "join fails without a list operand", %{conn: original_conn} do
    put(original_conn, @path <> "/drink", Poison.encode!(["water"]))
    conn = post(original_conn, @path <> "/drink", Poison.encode!(%{op: "join", value: "not_a_list"}))
    assert response(conn, 422)
  end
end
