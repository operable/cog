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
             "command_name" => "cog:s3",
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

  test "cannot create a rule without required permissions", %{unauthed: requestor} do
    command("s3")
    permission("cog:delete")
    rule_text = "when command is cog:s3 with option[op] == 'delete' must have cog:delete"

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
    permission("cog:delete")
    rule_text = "when command is cog:s3 with option[op] == 'delete' must have cog:delete"
    rule = rule(rule_text)

    assert_rule_is_persisted(rule.id, rule_text)

    conn = api_request(requestor, :delete, "/v1/rules/#{rule.id}")

    assert conn.status == 204

    refute_rule_is_persisted(rule_text)
  end

  test "404 if rule doesn't exist", %{authed: requestor} do
    conn = api_request(requestor, :delete, "/v1/rules/#{@bad_uuid}")
    assert "Rule #{@bad_uuid} not found" = json_response(conn, 404)["error"]
  end

  test "cannot delete a rule without required permissions", %{unauthed: requestor} do
    command("s3")
    permission("cog:delete")
    rule_text = "when command is cog:s3 with option[op] == 'delete' must have cog:delete"
    rule = rule(rule_text)

    conn = api_request(requestor, :delete, "/v1/rules/#{rule.id}")

    assert conn.halted
    assert conn.status == 403

    assert_rule_is_persisted(rule.id, rule_text)
  end

  # Show
  ########################################################################
  test "show the rules for a particular command", %{authed: requestor} do
    rule_text = "when command is cog:hola must have cog:hola"
    {:ok, version} = Cog.Repository.Bundles.install(
      %{"name" => "cog",
        "version" => "1.0.0",
        "config_file" => %{
          "name" => "cog",
          "version" => "1.0.0",
          "permissions" => ["cog:hola"],
          "commands" => %{"hola" => %{"rules" => [rule_text]}}}})

    permission("site:test")
    site_rule_text = "when command is cog:hola must have site:test"
    rule(site_rule_text)

    # Returns nothing if there isn't an enabled version
    conn = api_request(requestor, :get, "/v1/rules?for-command=cog:hola")
    assert "Command cog:hola not currently enabled; try enabling a bundle version first" = json_response(conn, 404)["errors"]

    # If we do enable a version, though, we get rules, including any
    # site rules we've specified
    Cog.Repository.Bundles.set_bundle_version_status(version, :enabled)
    conn = api_request(requestor, :get, "/v1/rules?for-command=cog:hola")

    rules = json_response(conn, 200)["rules"] |> Enum.sort_by(&Map.get(&1, "rule"))
    assert [%{"id" => _,
              "command_name" => "cog:hola",
              "rule" => ^rule_text},
            %{"id" => _,
              "command_name" => "cog:hola",
              "rule" => ^site_rule_text}] = rules
  end

  test "show error message for a non-existant command", %{authed: requestor} do
    command("hola")
    permission("cog:hola")

    conn = api_request(requestor, :get, "/v1/rules?for-command=cog:nada")
    assert %{"errors" => "Command cog:nada not found"} == json_response(conn, 422)

    conn = api_request(requestor, :get, "/v1/rules?command=cog:hola")
    assert %{"errors" => "Unknown parameters %{\"command\" => \"cog:hola\"}"} == json_response(conn, 422)
  end
end
