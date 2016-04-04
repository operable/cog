defmodule Cog.V1.EventHookControllerTest do
  use Cog.ModelCase
  use Cog.ConnCase

  alias Cog.Models.EventHook

  @bad_uuid "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"

  setup do
    # Requests handled by the role controller require this permission
    required_permission = permission("#{Cog.embedded_bundle}:manage_hooks")

    # This user will be used to test the normal operation of the controller
    authed_user = user("cog")
    |> with_token
    |> with_permission(required_permission)

    # This user will be used to verify that the above permission is
    # indeed required for requests
    unauthed_user = user("sadpanda") |> with_token

    {:ok, [authed: authed_user,
           unauthed: unauthed_user]}
  end

  test "index returns empty list when no hooks exist", %{authed: user} do
    conn = api_request(user, :get, "/v1/event_hooks")
    assert [] = json_response(conn, 200)["event_hooks"]
  end

  test "index returns multiple hooks when they exist", %{authed: user} do
    names = ["a","b","c"]
    hooks = names |> Enum.map(&hook(%{name: &1}))

    conn = api_request(user, :get, "/v1/event_hooks")
    retrieved = json_response(conn, 200)["event_hooks"]
    assert length(retrieved) == length(hooks)
    retrieved_names = Enum.map(retrieved, &(&1["name"]))

    for name <- names do
      assert name in retrieved_names
    end
  end

  test "can retrieve hook by ID", %{authed: user} do
    hook = hook(%{name: "echo"})
    conn = api_request(user, :get, "/v1/event_hooks/#{hook.id}")
    retrieved = json_response(conn, 200)["event_hook"]
    assert %{"name" => "echo"} = retrieved
  end

  test "retrieval by non-existent ID results in not found", %{authed: user} do
   conn = api_request(user, :get, "/v1/event_hooks/#{@bad_uuid}")
   assert "Hook not found" = json_response(conn, 404)["errors"]
  end

  test "retrieval by non-UUID ID results in bad request", %{authed: user} do
   conn = api_request(user, :get, "/v1/event_hooks/not-a-uuid")
   assert "Bad ID format" = json_response(conn, 400)["errors"]
  end

  test "hook creation works", %{authed: user} do
    conn = api_request(user, :post, "/v1/event_hooks",
                       body: %{"hook" => %{"name" => "my_hook",
                                           "pipeline" => "echo foo",
                                           "as_user" => "me"}})
    api_hook = json_response(conn, 201)["event_hook"]
    assert %{"name" => "my_hook"} = api_hook

    [location_header] = Plug.Conn.get_resp_header(conn, "location")
    assert "/v1/event_hooks/#{api_hook["id"]}" == location_header
  end

  test "hook creation fails with bad parameters", %{authed: user} do
    conn = api_request(user, :post, "/v1/event_hooks",
                       body: %{"hook" => %{}})
    assert json_response(conn, 422)["errors"]
  end

  test "hook editing works", %{authed: user} do
    %EventHook{id: id} = hook(%{name: "echo"})
    conn = api_request(user, :put, "/v1/event_hooks/#{id}",
                       body: %{"hook" => %{"name" => "foo"}})
    updated = json_response(conn, 200)["event_hook"]
    assert %{"id" => ^id,
             "name" => "foo"} = updated
  end

  test "hook editing fails with bad parameters", %{authed: user} do
    %EventHook{id: id} = hook(%{name: "echo"})
    conn = api_request(user, :put, "/v1/event_hooks/#{id}",
                       body: %{"hook" => %{"timeout_sec" => -100}})
    assert json_response(conn, 422)["errors"]
  end

  test "hook editing fails with bad ID", %{authed: user} do
    conn = api_request(user, :put, "/v1/event_hooks/not-a-uuid",
                       body: %{"hook" => %{"name" => "echooooo"}})
    assert "Bad ID format" = json_response(conn, 400)["errors"]
  end

  test "hook editing fails with non-existent hook", %{authed: user} do
    conn = api_request(user, :put, "/v1/event_hooks/#{@bad_uuid}",
                       body: %{"hook" => %{"name" => "echooooo"}})
    assert "Hook not found" = json_response(conn, 404)["errors"]
  end

  test "hook deletion works", %{authed: user} do
    hook = hook(%{name: "echo"})
    conn = api_request(user, :delete, "/v1/event_hooks/#{hook.id}")
    assert response(conn, 204)
  end

  test "cannot list hooks without permission", %{unauthed: user} do
    conn = api_request(user, :get, "/v1/event_hooks")
    assert conn.halted
    assert conn.status == 403
  end

  test "cannot create a hook without permission", %{unauthed: user} do
    conn = api_request(user, :post, "/v1/event_hooks",
                       body: %{})
    assert conn.halted
    assert conn.status == 403
  end

  test "cannot retrieve a hook without permission", %{unauthed: user} do
    hook = hook(%{name: "echo"})
    conn = api_request(user, :get, "/v1/event_hooks/#{hook.id}")
    assert conn.halted
    assert conn.status == 403
  end

  test "cannot edit a hook without permission", %{unauthed: user} do
    hook = hook(%{name: "echo"})
    conn = api_request(user, :put, "/v1/event_hooks/#{hook.id}",
                       body: %{})
    assert conn.halted
    assert conn.status == 403
  end

  test "cannot delete a hook without permission", %{unauthed: user} do
    hook = hook(%{name: "echo"})
    conn = api_request(user, :delete, "/v1/event_hooks/#{hook.id}")
    assert conn.halted
    assert conn.status == 403
  end

end
