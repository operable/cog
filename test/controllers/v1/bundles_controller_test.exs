defmodule Cog.V1.BundlesControllerTest do
  alias Ecto.DateTime

  use Cog.ModelCase
  use Cog.ConnCase

  setup do
    # Requests handled by the role controller require this permission
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

  setup_all do
    scratch_dir = Path.join([File.cwd!(), "test", "scratch", "*"])
    on_exit fn ->
      for file <- Path.wildcard(scratch_dir), do: File.rm_rf(file)
    end
  end

  # Test for the happy bundle config upload path
  Enum.map(Spanner.Config.config_extensions, &("config#{&1}"))
  |> Enum.each(fn(config_file) ->
    test "accepts a good #{config_file} file", %{authed: requestor} do
      config_file_name = unquote(config_file)
      config_path = if String.ends_with?(config_file_name, ".json") do
        # Make a json config if we have a file named config.json
        make_config_file(config_file_name, type: :json)
      else
        # Otherwise we can make a yaml config
        make_config_file(config_file_name, type: :yaml)
      end
      upload = %Plug.Upload{path: config_path, filename: config_file_name}

      conn = api_request(requestor, :post, "/v1/bundles", body: %{bundle_config: upload})

      assert conn.status == 201
    end
  end)

  test "rejects a file with an improper extension", %{authed: requestor} do
    filename = "config.jpg"

    config_path = make_config_file(filename)
    upload = %Plug.Upload{path: config_path, filename: filename}

    conn = api_request(requestor, :post, "/v1/bundles", body: %{bundle_config: upload})

    assert conn.status == 415
  end

  test "rejects an empty body", %{authed: requestor} do
    conn = api_request(requestor, :post, "/v1/bundles")

    assert conn.status == 400
  end

  test "rejects a bad config file", %{authed: requestor} do
    filename = "config.yaml"

    config_path = make_config_file(filename, contents: "---\nfoo: bar")
    upload = %Plug.Upload{path: config_path, filename: filename}

    conn = api_request(requestor, :post, "/v1/bundles", body: %{bundle_config: upload})

    assert conn.status == 422
  end

  test "rejects a malformed config file", %{authed: requestor} do
    filename = "config.yaml"

    config_path = make_config_file(filename, contents: "blah blah")
    upload = %Plug.Upload{path: config_path, filename: filename}

    conn = api_request(requestor, :post, "/v1/bundles", body: %{bundle_config: upload})

    assert conn.status == 422
  end

  test "shows chosen resource", %{authed: requestor} do
    bundle = bundle("test-1")
    conn = api_request(requestor, :get, "/v1/bundles/#{bundle.id}")
    assert %{"bundle" => %{"id" => bundle.id,
                           "name" => bundle.name,
                           "enabled" => bundle.enabled,
                           "relay_groups" => [],
                           "commands" => [],
                           "inserted_at" => "#{DateTime.to_iso8601(bundle.inserted_at)}",
                           "updated_at" => "#{DateTime.to_iso8601(bundle.updated_at)}"}} == json_response(conn, 200)
  end

  test "includes rules in bundle resource", %{authed: requestor} do
    bundle = bundle("cog")
    command = command("hola")
    permission("cog:hola")
    rule_text = "when command is cog:hola must have cog:hola"
    rule = rule(rule_text)

    bundle_id = bundle.id
    command_id = command.id
    rule_id = rule.id

    conn = api_request(requestor, :get, "/v1/bundles/#{bundle.id}")
    assert %{"bundle" => %{"id" => ^bundle_id,
                           "commands" => [
                             %{"id" => ^command_id,
                               "rules" => [
                                 %{"id" => ^rule_id,
                                   "command" => "cog:hola",
                                   "rule" => ^rule_text}]}]}} = json_response(conn, 200)
  end

  test "cannot view bundle without permission", %{unauthed: requestor} do
    bundle = bundle("test-1")
    conn = api_request(requestor, :get, "/v1/bundles/#{bundle.id}")
    assert conn.halted
    assert conn.status == 403
  end

  defp make_config_file(filename, options \\ []) do
    options = Keyword.merge([
      type: :yaml,
      contents: :nil
    ], options)

    config_path = Path.join([scratch_dir(), filename])
    file = File.open!(config_path, [:write, :utf8])

    if Keyword.get(options, :contents) do
      IO.write(file, Keyword.get(options, :contents))
    else
      IO.write(file, config(Keyword.get(options, :type)))
    end

    File.close(file)

    config_path
  end

  defp scratch_dir do
    path = Path.join([File.cwd!, "test", "scratch"])
    File.mkdir_p!(path)

    path
  end

  # simple config
  defp config(:yaml),
    do: config()
  defp config(:json) do
    Spanner.Config.Parser.read_from_string!(config())
    |> Poison.encode!
  end

  defp config do
    """
    ---
    # Format version
    cog_bundle_version: 2

    name: test_bundle
    version: 0.1.0
    permissions:
    - test_bundle:date
    - test_bundle:time
    docker:
      image: operable-bundle/test_bundle
      tag: v0.1.0
    commands:
      date:
        executable: /usr/local/bin/date
        options:
          option1:
            type: string
            description: An option
            required: false
            short_flag: o
        rules:
        - when command is test_bundle:date must have test_bundle:date
      time:
        executable: /usr/local/bin/time
        rules:
        - when command is test_bundle:time must have test_bundle:time
    templates:
      time:
        slack: "{{time}}"
        hipchat: "{{time}}"
      date:
        slack: "{{date}}"
        hipchat: "{{date}}"
    """
  end

end
