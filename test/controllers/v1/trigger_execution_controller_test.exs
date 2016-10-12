defmodule Cog.V1.TriggerExecutionControllerTest do
  use Cog.ModelCase
  use Cog.ConnCase

  alias Cog.Snoop

  @endpoint Cog.TriggerEndpoint
  @bad_uuid "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"

  setup context do
    content_type = case context[:content_type] do
      nil  -> "application/json"
      type -> type
    end

    conn = build_conn()
    |> put_req_header("content-type", content_type)
    {:ok, conn: conn}
  end

  test "simple round trip works", %{conn: conn} do
    {:ok, snoop} = Snoop.adapter_traffic

    user("cog")
    trigger = trigger(%{name: "echo",
                  pipeline: "echo foo",
                  as_user: "cog"})

    conn = post(conn, "/v1/triggers/#{trigger.id}", Poison.encode!(%{}))
    assert [%{"body" => ["foo"]}] = json_response(conn, 200)

    # The chat adapter shouldn't have gotten anything, since we didn't
    # redirect to it.
    Snoop.assert_no_message_received(snoop, provider: "test")
    assert [[%{"body" => ["foo"]}]] = Snoop.loop_until_received(snoop, provider: "http")
  end

  test "executing a non-existent trigger fails", %{conn: conn} do
    conn = post(conn, "/v1/triggers/#{@bad_uuid}", %{})
    assert "Trigger not found" = json_response(conn, 404)["errors"]
  end

  test "passing a non-UUID ID fails fails", %{conn: conn} do
    conn = post(conn, "/v1/triggers/not-a-uuid", %{})
    assert "Bad ID format" = json_response(conn, 400)["errors"]
  end

  test "executing a trigger as a non-existent user fails", %{conn: conn} do
    trigger = trigger(%{name: "echo",
                  pipeline: "echo foo",
                  as_user: "nobody_i_know"})

    conn = post(conn, "/v1/triggers/#{trigger.id}", %{})
    assert "Configured trigger user does not exist" = json_response(conn, 422)["errors"]
  end

  test "redirecting elsewhere results in 204 (OK, no content), as well as a message to the chat adapter", %{conn: conn} do
    {:ok, snoop} = Snoop.adapter_traffic

    # Set up initial data
    user("cog")
    trigger = trigger(%{name: "echo",
                        pipeline: "echo foo > chat://#general",
                        as_user: "cog"})

    # Make the request
    conn = post(conn, "/v1/triggers/#{trigger.id}", Poison.encode!(%{}))

    # The HTTP response should be successful
    assert response(conn, 204)

    # And the adapter should get a message, too
    assert ["foo"] = Snoop.loop_until_received(snoop, provider: "test")
  end

  test "errors only go back to the request, not any chat adapters", %{conn: conn} do
    {:ok, snoop} = Snoop.adapter_traffic

    user("cog")
    trigger = trigger(%{name: "echo",
                  pipeline: "echo $body.not_a_key > chat://#general",
                  as_user: "cog"})

    # Make the request; the pipeline will fail because there isn't a
    # `not_a_key` key in the body
    conn = post(conn, "/v1/triggers/#{trigger.id}", Poison.encode!(%{}))

    # The HTTP response should reflect an error
    message = json_response(conn, 500)["errors"]["error_message"]
    assert message == "I can't find the variable '$not_a_key'."

    # And the adapter should not get a message, even though we redirected
    Snoop.assert_no_message_received(snoop, provider: "test")
    [error_msg] = Snoop.loop_until_received(snoop, provider: "http")
    assert Map.get(error_msg,
                   "error_message") == "I can't find the variable '$not_a_key'."
  end

  test "disabled triggers don't fire", %{conn: conn} do
    user("cog")
    trigger = trigger(%{name: "echo",
                        pipeline: "echo foo",
                        as_user: "cog",
                        enabled: false})

    conn = post(conn, "/v1/triggers/#{trigger.id}", Poison.encode!(%{}))
    assert "Trigger is not enabled" = json_response(conn, 422)["errors"]
  end

  test "request sent to executor is correctly set up", %{conn: conn} do
    # Snoop on messages sent to the executor
    {:ok, executor_snoop} = Snoop.incoming_executor_traffic

    # Set up initial data
    pipeline_text = "echo $body.message $query_params.thing $headers.content-type"
    username = "cog"
    user(username)
    trigger = trigger(%{name: "echo",
                  pipeline: pipeline_text,
                  as_user: username})
    trigger_id = trigger.id

    # Make the request
    body = %{"message" => "this"}
    json = Poison.encode!(body)

    conn = post(conn, "/v1/triggers/#{trigger_id}?thing=responds_to", json)
    assert [%{"body" => ["this responds_to application/json"]}] = json_response(conn, 200)

    # Check that the executor got the context we expected
    [message] = Snoop.messages(executor_snoop)

    assert %{"id" => request_id,
             "adapter" => "http",
             "room" => %{"id" => request_id},
             "sender" => %{"id" => ^username},
             "initial_context" => %{"trigger_id" => ^trigger_id,
                                    "headers" => %{"content-type" => "application/json"},
                                    "raw_body" => ^json,
                                    "body" => ^body,
                                    "query_params" => %{"thing" => "responds_to"}},
             "text" => ^pipeline_text} = message

    # Just to be absolutely certain...
    refute trigger_id == request_id
  end

  test "a trigger with no user executed without a token fails", %{conn: conn} do
    trigger = trigger(%{name: "echo",
                  pipeline: "echo foo",
                  as_user: nil})
    assert nil == trigger.as_user

    # Make the request
    conn = post(conn, "/v1/triggers/#{trigger.id}",
                Poison.encode!(%{}))

    # No trigger user, no authentication token => no execution
    assert [] = Plug.Conn.get_req_header(conn, "authorization")
    assert response(conn, 401)
  end

  test "a trigger with no user executes as the tokened user" do
    tokened_user = user("cog") |> with_token

    trigger = trigger(%{name: "list-permissions",
                  pipeline: "permission list",
                  as_user: nil})
    assert nil == trigger.as_user

    # Before the requestor has the necessary permission, execution of
    # the trigger fails
    conn = api_request(tokened_user, :post, "/v1/triggers/#{trigger.id}", body: %{}, endpoint: Cog.TriggerEndpoint)
    assert ["token " <> _] = Plug.Conn.get_req_header(conn, "authorization")
    message = json_response(conn, 500)["errors"]["error_message"]
    assert message =~ "You will need at least one of the following permissions to run this command: 'operable:manage_permissions'."

    # Give the requestor the required permission
    permission = permission("operable:manage_permissions")
    tokened_user |> with_permission(permission)
    assert Cog.Models.User.has_permission(tokened_user, permission)

    # PURGE THE CACHE :(
    Cog.Command.PermissionsCache.reset_cache

    # Now that the requestor has the permission, trigger execution succeeds
    {:ok, executor_snoop} = Snoop.incoming_executor_traffic
    conn = api_request(tokened_user, :post, "/v1/triggers/#{trigger.id}", body: %{}, endpoint: Cog.TriggerEndpoint)
    assert ["token " <> _] = Plug.Conn.get_req_header(conn, "authorization")
    assert response(conn, 200)

    # And we verify that the pipeline executed as the requestor
    [message] = Snoop.messages(executor_snoop)
    requestor_username = tokened_user.username
    assert %{"sender" => %{"id" => ^requestor_username}} = message
  end

  test "the trigger's specified user overrides any token there might be in a request", %{conn: _conn} do
    {:ok, executor_snoop} = Snoop.incoming_executor_traffic

    permission = permission("operable:manage_permissions")
    trigger_user = user("captain_hook") |> with_permission(permission)
    requestor = user("mr_smee") |> with_token

    refute Cog.Models.User.has_permission(requestor, permission)

    # Create a trigger running a pipeline that requires the permission
    trigger = trigger(%{name: "list-permissions",
                  pipeline: "permission list",
                  as_user: "captain_hook"})

    conn = api_request(requestor, :post, "/v1/triggers/#{trigger.id}", body: %{}, endpoint: Cog.TriggerEndpoint)
    assert ["token " <> _] = Plug.Conn.get_req_header(conn, "authorization")

    # The requestor doesn't have the permission, but the trigger user
    # does.
    assert response(conn, 200)

    # And we can verify that the pipeline was executed as the trigger
    # user and not the requestor
    [message] = Snoop.messages(executor_snoop)
    trigger_user_name = trigger_user.username
    assert %{"sender" => %{"id" => ^trigger_user_name}} = message
  end

  test "execution that goes beyond the specified timeout returns 202, but continues processing", %{conn: conn} do
    {:ok, snoop} = Snoop.adapter_traffic

    user("cog")

    # Our trigger will timeout before the pipeline finishes
    timeout_sec = 2
    set_timeout_buffer(1)
    trigger = trigger(%{name: "sleepytime",
                        pipeline: "echo Hello | sleep #{timeout_sec} | echo $body[0] > chat://#general",
                        as_user: "cog",
                        timeout_sec: timeout_sec})

    # Make the request
    conn = post(conn, "/v1/triggers/#{trigger.id}", Poison.encode!(%{}))

    %{"id" => _,
      "status" => status} = json_response(conn, 202)
    assert "Request accepted and still processing after #{timeout_sec} seconds" == status

    assert ["Hello"] = Snoop.loop_until_received(snoop, provider: "test")
    assert ["ok"] = Snoop.loop_until_received(snoop, provider: "http")
  end

  @tag content_type: "text/plain"
  test "requires JSON or x-www-form-urlencoded content", %{conn: conn} do
    user("cog")
    trigger = trigger(%{name: "echo",
                  pipeline: "echo foo",
                  as_user: "cog"})
    conn = post(conn, "/v1/triggers/#{trigger.id}", "Hello World")

    assert conn.halted
    assert 415 = conn.status
  end

  test "JSON payloads are mapped to cog_env variables", %{conn: conn} do

    user("cog")
    trigger = trigger(%{name: "echo",
                  pipeline: "echo $body.test_key $body.other_key",
                  as_user: "cog"})

    payload = %{test_key: "test_value", other_key: "other_value"}
    conn = post(conn, "/v1/triggers/#{trigger.id}", Poison.encode!(payload))
    message = json_response(conn, 200)

    assert [%{"body" => ["test_value other_value"]}] == message
  end

  @tag content_type: "application/x-www-form-urlencoded"
  test "x-www-form-urlencoded payloads are mapped to cog_env variables", %{conn: conn} do

    user("cog")
    trigger = trigger(%{name: "echo",
                  pipeline: "echo $body.test_key $body.other_key",
                  as_user: "cog"})

    payload = %{test_key: "test_value", other_key: "other_value"}
    conn = post(conn, "/v1/triggers/#{trigger.id}", URI.encode_query(payload))
    message = json_response(conn, 200)

    assert [%{"body" => ["#{payload[:test_key]} #{payload[:other_key]}"]}] == message
  end

  test "an empty body is treated as an empty JSON map", %{conn: conn} do
    {:ok, executor_snoop} = Snoop.incoming_executor_traffic
    user("cog")
    trigger = trigger(%{name: "echo",
                        pipeline: "echo foo",
                        as_user: "cog"})
    conn = post(conn, "/v1/triggers/#{trigger.id}")

    assert [%{"body" => ["foo"]}] = json_response(conn, 200)

    [message] = Snoop.messages(executor_snoop)
    assert %{} == get_in(message, ["initial_context", "body"])
  end

  test "early-terminating pipeline doesn't send messages to chat destinations", %{conn: conn} do

    {:ok, snoop} = Snoop.adapter_traffic

    user("cog")
    trigger = trigger(%{name: "echo",
                        pipeline: "filter --path='baz' | echo $foo *> here chat://#general",
                        as_user: "cog"})

    conn = post(conn, "/v1/triggers/#{trigger.id}", Poison.encode!(%{foo: "bar"}))

    # We should get a success message back in the response
    message = json_response(conn, 200)
    assert message == %{}

    # And the adapter should not get a message, even though we redirected
    Snoop.assert_no_message_received(snoop, provider: "test")
    assert [%{}] = Snoop.loop_until_received(snoop, provider: "http")
  end

  ########################################################################

  defp set_timeout_buffer(new_buffer) do
    old_buffer = Application.get_env(:cog, :trigger_timeout_buffer)
    on_exit(fn() -> Application.put_env(:cog, :trigger_timeout_buffer, old_buffer) end)
    Application.put_env(:cog, :trigger_timeout_buffer, new_buffer)
  end
end
