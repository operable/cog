defmodule Cog.V1.RuleController.Test do
  use Cog.ModelCase
  use Cog.ConnCase

  @bad_uuid "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"

  setup do
    required_permission = permission("#{Cog.embedded_bundle}:manage_commands")

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

  # Create
  ########################################################################

  test "creates a new rule when rule is valid", %{authed: requestor} do
    command("s3")
    permission("cog:delete")
    rule_text = "when command is cog:s3 with option[op] == 'delete' must have cog:delete"

    conn = api_request(requestor, :post, "/v1/rules",
                       body: %{"rule" => rule_text})

    body = json_response(conn, 201)
    id = body["id"]

    assert %{"id" => id,
            "rule" => rule_text} == body

    # TODO: we don't provide a GET for rules just yet
    # expected_location = "/v1/rules/#{id}"
    # assert expected_location == redirected_to(conn, 201)

    assert_rule_is_persisted(id, rule_text)
  end

  test "fails to create a rule if the command does not exist", %{authed: requestor} do
    permission("site:admin")
    rule_text = "when command is cog:do_stuff must have site:admin"

    conn = api_request(requestor, :post, "/v1/rules",
                       body: %{"rule" => rule_text})

    assert %{"errors" =>
              %{"unrecognized_command" => ["cog:do_stuff"]}} == json_response(conn, 422)

    refute_rule_is_persisted(rule_text)
  end

  test "fails to create a rule if permissions do not exist", %{authed: requestor} do
    command("do_stuff")
    rule_text = "when command is cog:do_stuff must have do_stuff:admin"

    conn = api_request(requestor, :post, "/v1/rules",
                       body: %{"rule" => rule_text})

    assert %{"errors" =>
              %{"unrecognized_permission" => ["do_stuff:admin"]}} == json_response(conn, 422)

    refute_rule_is_persisted(rule_text)
  end

  test "errors accumulate", %{authed: requestor} do
    permission("site:admin")
    rule_text = "when command is cog:do_stuff must have site:admin and do_stuff:things and do_stuff:other_stuff"

    conn = api_request(requestor, :post, "/v1/rules",
                       body: %{"rule" => rule_text})

    assert %{"errors" =>
              %{"unrecognized_command" => ["cog:do_stuff"],
                "unrecognized_permission" => ["do_stuff:things",
                                              "do_stuff:other_stuff"]}} == json_response(conn, 422)

    refute_rule_is_persisted(rule_text)
  end

  test "cannot create a rule without required permissions", %{unauthed: requestor} do
    command("s3")
    permission("s3:delete")
    rule_text = "when command is cog:s3 with option[op] == 'delete' must have s3:delete"

    conn = api_request(requestor, :post, "/v1/rules",
                       body: %{"rule" => rule_text})

    assert conn.halted
    assert conn.status == 403

    refute_rule_is_persisted(rule_text)
  end

  # Delete
  ########################################################################

  test "delete an existing rule", %{authed: requestor} do
    command("s3")
    permission("s3:delete")
    rule_text = "when command is cog:s3 with option[op] == 'delete' must have s3:delete"
    rule = rule(rule_text)

    assert_rule_is_persisted(rule.id, rule_text)

    conn = api_request(requestor, :delete, "/v1/rules/#{rule.id}")

    assert conn.status == 204

    refute_rule_is_persisted(rule_text)
  end

  test "404 if rule doesn't exist", %{authed: requestor} do
    error = catch_error(api_request(requestor, :delete, "/v1/rules/#{@bad_uuid}"))
    assert %Ecto.NoResultsError{} = error
  end

  test "cannot delete a rule without required permissions", %{unauthed: requestor} do
    command("s3")
    permission("s3:delete")
    rule_text = "when command is cog:s3 with option[op] == 'delete' must have s3:delete"
    rule = rule(rule_text)

    conn = api_request(requestor, :delete, "/v1/rules/#{rule.id}")

    assert conn.halted
    assert conn.status == 403

    assert_rule_is_persisted(rule.id, rule_text)
  end

  # Show
  ########################################################################
  test "show the rules for a particular command", %{authed: requestor} do
    command("hola")
    permission("cog:hola")
    rule_text = "when command is cog:hola must have cog:hola"
    rule = rule(rule_text)

    conn = api_request(requestor, :get, "/v1/rules?for-command=cog:hola")

    assert %{"rules" => [%{"id" => rule.id,
                           "command" => "cog:hola",
                           "rule" => rule_text}]} == json_response(conn, 200)
  end

  test "show error message for a non-existant command", %{authed: requestor} do
    command("hola")
    permission("cog:hola")

    conn = api_request(requestor, :get, "/v1/rules?for-command=cog:nada")
    assert %{"errors" => "No rules for command found"} == json_response(conn, 422)

    conn = api_request(requestor, :get, "/v1/rules?command=cog:hola")
    assert %{"errors" => "Unknown parameters %{\"command\" => \"cog:hola\"}"} == json_response(conn, 422)
  end
end
