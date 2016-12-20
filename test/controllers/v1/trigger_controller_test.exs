defmodule Cog.V1.TriggerControllerTest do
  use Cog.ModelCase
  use Cog.ConnCase

  alias Cog.Models.Trigger

  @bad_uuid "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"

  setup do
    # Requests handled by the role controller require this permission
    required_permission = permission("#{Cog.Util.Misc.embedded_bundle}:manage_triggers")

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

  test "index returns empty list when no triggers exist", %{authed: user} do
    conn = api_request(user, :get, "/v1/triggers")
    assert [] = json_response(conn, 200)["triggers"]
  end

  test "index returns multiple triggers when they exist", %{authed: user} do
    names = ["a","b","c"]
    triggers = names |> Enum.map(&trigger(%{name: &1}))

    conn = api_request(user, :get, "/v1/triggers")
    retrieved = json_response(conn, 200)["triggers"]
    assert length(retrieved) == length(triggers)
    retrieved_names = Enum.map(retrieved, &(&1["name"]))

    for name <- names do
      assert name in retrieved_names
    end
  end

  test "index with query parameters acts as search", %{authed: user} do
    ["a","b","c"] |> Enum.map(&trigger(%{name: &1}))

    conn = api_request(user, :get, "/v1/triggers?name=a")
    assert [%{"name" => "a"}] = json_response(conn, 200)["triggers"]
  end

  test "can retrieve trigger by ID", %{authed: user} do
    trigger = trigger(%{name: "echo"})
    conn = api_request(user, :get, "/v1/triggers/#{trigger.id}")
    retrieved = json_response(conn, 200)["trigger"]
    assert %{"name" => "echo"} = retrieved
  end

  test "retrieval by non-existent ID results in not found", %{authed: user} do
   conn = api_request(user, :get, "/v1/triggers/#{@bad_uuid}")
   assert "Trigger not found" = json_response(conn, 404)["errors"]
  end

  test "retrieval by non-UUID ID results in bad request", %{authed: user} do
   conn = api_request(user, :get, "/v1/triggers/not-a-uuid")
   assert "Bad ID format" = json_response(conn, 400)["errors"]
  end

  test "trigger creation works", %{authed: user} do
    conn = api_request(user, :post, "/v1/triggers",
                       body: %{"trigger" => %{"name" => "my_trigger",
                                              "pipeline" => "echo foo",
                                              "as_user" => user.username}})
    api_trigger = json_response(conn, 201)["trigger"]
    assert %{"name" => "my_trigger"} = api_trigger

    [location_header] = Plug.Conn.get_resp_header(conn, "location")
    assert "/v1/triggers/#{api_trigger["id"]}" == location_header
  end

  test "trigger creation fails with bad parameters", %{authed: user} do
    conn = api_request(user, :post, "/v1/triggers",
                       body: %{"trigger" => %{}})
    assert json_response(conn, 422)["errors"]
  end

  test "trigger editing works", %{authed: user} do
    %Trigger{id: id} = trigger(%{name: "echo"})
    conn = api_request(user, :put, "/v1/triggers/#{id}",
                       body: %{"trigger" => %{"name" => "foo"}})
    updated = json_response(conn, 200)["trigger"]
    assert %{"id" => ^id,
             "name" => "foo"} = updated
  end

  test "trigger creation with non-existent user fails", %{authed: user} do
    conn = api_request(user,
                       :post, "/v1/triggers",
                       body: %{"trigger" => %{name: "echo",
                                              pipeline: "echo foo",
                                              as_user: "who_is_this"}})

    assert %{"as_user" => ["does not exist"]} == json_response(conn, 422)["errors"]
  end

  test "trigger editing fails with bad parameters", %{authed: user} do
    %Trigger{id: id} = trigger(%{name: "echo"})
    conn = api_request(user, :put, "/v1/triggers/#{id}",
                       body: %{"trigger" => %{"timeout_sec" => -100}})
    assert json_response(conn, 422)["errors"]
  end

  test "trigger editing fails with bad ID", %{authed: user} do
    conn = api_request(user, :put, "/v1/triggers/not-a-uuid",
                       body: %{"trigger" => %{"name" => "echooooo"}})
    assert "Bad ID format" = json_response(conn, 400)["errors"]
  end

  test "trigger editing fails with non-existent trigger", %{authed: user} do
    conn = api_request(user, :put, "/v1/triggers/#{@bad_uuid}",
                       body: %{"trigger" => %{"name" => "echooooo"}})
    assert "Trigger not found" = json_response(conn, 404)["errors"]
  end

  test "trigger deletion works", %{authed: user} do
    trigger = trigger(%{name: "echo"})
    conn = api_request(user, :delete, "/v1/triggers/#{trigger.id}")
    assert response(conn, 204)
  end

  test "cannot list triggers without permission", %{unauthed: user} do
    conn = api_request(user, :get, "/v1/triggers")
    assert conn.halted
    assert conn.status == 403
  end

  test "cannot create a trigger without permission", %{unauthed: user} do
    conn = api_request(user, :post, "/v1/triggers",
                       body: %{})
    assert conn.halted
    assert conn.status == 403
  end

  test "cannot retrieve a trigger without permission", %{unauthed: user} do
    trigger = trigger(%{name: "echo"})
    conn = api_request(user, :get, "/v1/triggers/#{trigger.id}")
    assert conn.halted
    assert conn.status == 403
  end

  test "cannot edit a trigger without permission", %{unauthed: user} do
    trigger = trigger(%{name: "echo"})
    conn = api_request(user, :put, "/v1/triggers/#{trigger.id}",
                       body: %{})
    assert conn.halted
    assert conn.status == 403
  end

  test "cannot delete a trigger without permission", %{unauthed: user} do
    trigger = trigger(%{name: "echo"})
    conn = api_request(user, :delete, "/v1/triggers/#{trigger.id}")
    assert conn.halted
    assert conn.status == 403
  end

end
