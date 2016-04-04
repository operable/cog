defmodule Cog.V1.EventHookExecutionControllerTest do
  use Cog.ModelCase
  use Cog.ConnCase

  alias Cog.Snoop

  @endpoint Cog.EventHookEndpoint
  @bad_uuid "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"

  setup do
    conn = conn()
    |> put_req_header("content-type", "application/json")
    {:ok, conn: conn}
  end

  test "simple round trip works", %{conn: conn} do
    assert {:ok, Cog.Adapters.Test} = Cog.chat_adapter_module
    {:ok, snoop} = Snoop.start_link("/bot/adapters/test/send_message")

    user("cog")
    hook = hook(%{name: "echo",
                  pipeline: "echo foo",
                  as_user: "cog"})

    conn = post(conn, "/v1/event_hooks/#{hook.id}", Poison.encode!(%{}))
    assert "foo" = json_response(conn, 200)

    # The chat adapter shouldn't have gotten anything, since we didn't
    # redirect to it.
    assert [] = Snoop.messages(snoop)
  end

  test "executing a non-existent hook fails", %{conn: conn} do
    conn = post(conn, "/v1/event_hooks/#{@bad_uuid}", %{})
    assert "Hook not found" = json_response(conn, 404)["errors"]
  end

  test "passing a non-UUID ID fails fails", %{conn: conn} do
    conn = post(conn, "/v1/event_hooks/not-a-uuid", %{})
    assert "Bad ID format" = json_response(conn, 400)["errors"]
  end

  test "executing a hook as a non-existent user fails", %{conn: conn} do
    hook = hook(%{name: "echo",
                  pipeline: "echo foo",
                  as_user: "nobody_i_know"})

    conn = post(conn, "/v1/event_hooks/#{hook.id}", %{})
    assert "Configured hook user does not exist" = json_response(conn, 422)["errors"]
  end

  test "redirecting elsewhere results in 204 (OK, no content), as well as a message to the chat adapter", %{conn: conn} do
    # Verify that we're using the "test" chat adapter, and then listen
    # for responses sent to it
    assert {:ok, Cog.Adapters.Test} = Cog.chat_adapter_module
    {:ok, test_snoop} = Snoop.start_link("/bot/adapters/test/send_message")

    # Set up initial data
    user("cog")
    hook = hook(%{name: "echo",
                  pipeline: "echo foo > chat://#general",
                  as_user: "cog"})

    # Make the request
    conn = post(conn, "/v1/event_hooks/#{hook.id}", Poison.encode!(%{}))

    # The HTTP response should be successful
    assert response(conn, 204)

    # And the adapter should get a message, too
    [message] = Snoop.messages(test_snoop)
    expected_response = Poison.encode!(%{body: ["foo"]}, pretty: true)
    assert %{"response" => ^expected_response} = message
  end

  test "errors only go back to the request, not any chat adapters", %{conn: conn} do
    assert {:ok, Cog.Adapters.Test} = Cog.chat_adapter_module
    {:ok, test_snoop} = Snoop.start_link("/bot/adapters/test/send_message")

    user("cog")
    hook = hook(%{name: "echo",
                  pipeline: "echo $body.not_a_key > chat://#general",
                  as_user: "cog"})

    # Make the request; the pipeline will fail because there isn't a
    # `not_a_key` key in the body
    conn = post(conn, "/v1/event_hooks/#{hook.id}", Poison.encode!(%{}))

    # The HTTP response should reflect an error
    message = json_response(conn, 500)["errors"]
    assert message =~ "An error has occurred"

    # And the adapter should not get a message, even though we redirected
    assert [] = Snoop.messages(test_snoop)
  end

  test "inactive hooks don't fire", %{conn: conn} do
    user("cog")
    hook = hook(%{name: "echo",
                  pipeline: "echo foo",
                  as_user: "cog",
                  active: false})

    conn = post(conn, "/v1/event_hooks/#{hook.id}", Poison.encode!(%{}))
    assert "Hook is not active" = json_response(conn, 422)["errors"]
  end

  test "request sent to executor is correctly set up", %{conn: conn} do
    # Snoop on messages sent to the executor
    {:ok, executor_snoop} = Snoop.start_link("/bot/commands")

    # Set up initial data
    pipeline_text = "echo $body.message $query_params.thing $headers.content-type"
    username = "cog"
    user(username)
    hook = hook(%{name: "echo",
                  pipeline: pipeline_text,
                  as_user: username})
    hook_id = hook.id

    # Make the request
    conn = post(conn, "/v1/event_hooks/#{hook_id}?thing=responds_to",
                Poison.encode!(%{"message" => "this"}))
    assert "this responds_to application/json" = json_response(conn, 200)

    # Check that the executor got the context we expected
    [message] = Snoop.messages(executor_snoop)
    assert %{"id" => request_id,
             "adapter" => "http",
             "module" => "Elixir.Cog.Adapters.Http",
             "reply" => "/bot/adapters/http/send_message",
             "room" => %{"id" => request_id},
             "sender" => %{"id" => ^username},
             "initial_context" => %{"hook_id" => ^hook_id,
                                    "headers" => %{"content-type" => "application/json"},
                                    "body" => %{"message" => "this"},
                                    "query_params" => %{"thing" => "responds_to"}},
             "text" => ^pipeline_text} = message

    # Just to be absolutely certain...
    refute hook_id == request_id
  end

  test "a hook with no user executed without a token fails", %{conn: conn} do
    hook = hook(%{name: "echo",
                  pipeline: "echo foo",
                  as_user: nil})
    assert nil == hook.as_user

    # Make the request
    conn = post(conn, "/v1/event_hooks/#{hook.id}",
                Poison.encode!(%{}))

    # No hook user, no authentication token => no execution
    assert [] = Plug.Conn.get_req_header(conn, "authorization")
    assert response(conn, 401)
  end

  test "a hook with no user executes as the tokened user" do
    tokened_user = user("cog") |> with_token

    hook = hook(%{name: "list-permissions",
                  pipeline: "permissions --list",
                  as_user: nil})
    assert nil == hook.as_user

    # Before the requestor has the necessary permission, execution of
    # the hook fails
    conn = api_request(tokened_user, :post, "/v1/event_hooks/#{hook.id}", body: %{}, endpoint: Cog.EventHookEndpoint)
    assert ["token " <> _] = Plug.Conn.get_req_header(conn, "authorization")
    message = json_response(conn, 500)["errors"]
    assert message =~ "You will need the 'operable:manage_permissions' permission to run this command"

    # Give the requestor the required permission
    permission = permission("operable:manage_permissions")
    tokened_user |> with_permission(permission)
    assert Cog.Models.User.has_permission(tokened_user, permission)

    # PURGE THE CACHE :(
    Cog.Command.PermissionsCache.reset_cache

    # Now that the requestor has the permission, hook execution succeeds
    {:ok, executor_snoop} = Snoop.start_link("/bot/commands")
    conn = api_request(tokened_user, :post, "/v1/event_hooks/#{hook.id}", body: %{}, endpoint: Cog.EventHookEndpoint)
    assert ["token " <> _] = Plug.Conn.get_req_header(conn, "authorization")
    require Logger

    Logger.warn(">>>>>>> conn = #{inspect conn}")

    assert response(conn, 200)

    # And we verify that the pipeline executed as the requestor
    [message] = Snoop.messages(executor_snoop)
    requestor_username = tokened_user.username
    assert %{"sender" => %{"id" => ^requestor_username}} = message
  end

  test "the hook's specified user overrides any token there might be in a request", %{conn: _conn} do
    {:ok, executor_snoop} = Snoop.start_link("/bot/commands")

    permission = permission("operable:manage_permissions")
    hook_user = user("captain_hook") |> with_permission(permission)
    requestor = user("mr_smee") |> with_token

    refute Cog.Models.User.has_permission(requestor, permission)

    # Create a hook running a pipeline that requires the permission
    hook = hook(%{name: "list-permissions",
                  pipeline: "permissions --list",
                  as_user: "captain_hook"})

    conn = api_request(requestor, :post, "/v1/event_hooks/#{hook.id}", body: %{}, endpoint: Cog.EventHookEndpoint)
    assert ["token " <> _] = Plug.Conn.get_req_header(conn, "authorization")

    # The requestor doesn't have the permission, but the hook user
    # does.
    assert response(conn, 200)

    # And we can verify that the pipeline was executed as the hook
    # user and not the requestor
    [message] = Snoop.messages(executor_snoop)
    hook_user_name = hook_user.username
    assert %{"sender" => %{"id" => ^hook_user_name}} = message
  end

end
