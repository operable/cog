defmodule Cog.V1.BundlesControllerTest do

  require Logger

  use Cog.ModelCase
  use Cog.ConnCase

  alias Cog.Repository.Bundles

  @bad_uuid "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"

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

      # upload the config
      conn = api_request(requestor, :post, "/v1/bundles", body: %{bundle: %{config_file: upload}}, content_type: :multipart)

      bundle_id = Poison.decode!(conn.resp_body) |> get_in(["bundle_version", "id"])

      bundle_version = Cog.Repo.get_by(Cog.Models.BundleVersion, id: bundle_id) |> Repo.preload(:bundle)
      config = Spanner.Config.Parser.read_from_file!(config_path)

      assert conn.status == 201
      [location_header] = Plug.Conn.get_resp_header(conn, "location")
      assert "/v1/bundles/#{bundle_version.bundle.id}/versions/#{bundle_version.id}" == location_header

      assert bundle_version.config_file == config
      assert bundle_version.bundle.name == config["name"]
    end
  end)

  test "accepts an upgradable config", %{authed: requestor} do
    config_path = make_config_file("old_config.yaml", contents: old_config)
    upload = %Plug.Upload{path: config_path, filename: "old_config.yaml"}

    conn = api_request(requestor, :post, "/v1/bundles", body: %{bundle: %{config_file: upload}}, content_type: :multipart)

    response = Poison.decode!(conn.resp_body)

    warnings = get_in(response, ["warnings"])
    bundle_version_id = get_in(response, ["bundle_version", "id"])
    bundle_version = Cog.Repository.Bundles.version(bundle_version_id)
    config = Spanner.Config.Parser.read_from_file!(config_path)

    assert conn.status == 201
    assert bundle_version.bundle.name == config["name"]
    assert warnings == [
      "Warning near #/cog_bundle_version: Bundle config version 2 has been deprecated. Please update to version 3.",
      "Warning near #/commands/date/enforcing: Non-enforcing commands have been deprecated. Please update your bundle config to version 3."]
  end

  test "rejects a file with an improper extension", %{authed: requestor} do
    filename = "config.jpg"

    config_path = make_config_file(filename)
    upload = %Plug.Upload{path: config_path, filename: filename}

    conn = api_request(requestor, :post, "/v1/bundles", body: %{bundle: %{config_file: upload}}, content_type: :multipart)

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

    conn = api_request(requestor, :post, "/v1/bundles", body: %{bundle: %{config_file: upload}}, content_type: :multipart)

    assert conn.status == 422
  end

  test "rejects a malformed config file", %{authed: requestor} do
    filename = "config.yaml"

    config_path = make_config_file(filename, contents: "blah blah")
    upload = %Plug.Upload{path: config_path, filename: filename}

    conn = api_request(requestor, :post, "/v1/bundles", body: %{bundle: %{config_file: upload}}, content_type: :multipart)

    assert conn.status == 422
  end

  test "accepts a valid config passed as json", %{authed: requestor} do
    config = config(:map)
    conn = api_request(requestor, :post, "/v1/bundles", body: %{"bundle" => %{"config" => config}})

    body = conn.resp_body

    bundle_version_id = Poison.decode!(body)
                |> get_in(["bundle_version", "id"])

    bundle_version = Cog.Repository.Bundles.version(bundle_version_id)

    assert conn.status == 201
    assert bundle_version.config_file == config
    assert bundle_version.bundle.name == config["name"]
  end

  test "rejects a bad config passed as json", %{authed: requestor} do
    conn = api_request(requestor, :post, "/v1/bundles", body: %{"bad" => "config"})

    assert conn.status == 400
  end

  test "fails to install the same version twice", %{authed: requestor} do
    config = config(:map)
    conn = api_request(requestor, :post, "/v1/bundles", body: %{"bundle" => %{"config" => config}})
    assert response(conn, 201)

    # Now try to do the same thing again
    conn = api_request(requestor, :post, "/v1/bundles", body: %{"bundle" => %{"config" => config}})
    assert ["Could not save bundle.",
            "version has already been taken"] = json_response(conn, 409)["errors"]
  end

  test "fails to install with semantically invalid config", %{authed: requestor} do
    # The config includes rules that mention permissions; if we remove
    # those permissions, installation should fail
    config = config(:map) |> Map.put("permissions", [])

    conn = api_request(requestor, :post, "/v1/bundles", body: %{"bundle" => %{"config" => config}})
    assert json_response(conn, 422)["errors"]
  end

  test "shows disabled bundle", %{authed: requestor} do
    {:ok, _version3} = Bundles.install(%{"name" => "foo", "version" => "3.0.0", "config_file" => %{}})
    {:ok, _version2} = Bundles.install(%{"name" => "foo", "version" => "2.0.0", "config_file" => %{}})
    {:ok, version1} = Bundles.install(%{"name" => "foo", "version" => "1.0.0", "config_file" => %{}})

    bundle = version1.bundle

    conn = api_request(requestor, :get, "/v1/bundles/#{bundle.id}")

    bundle_id = bundle.id
    bundle_name = bundle.name
    assert %{"bundle" => %{"id" => ^bundle_id,
                           "name" => ^bundle_name,
                           "enabled_version" => nil,
                           "versions" => [%{"id" => _, "version" => "3.0.0"},
                                          %{"id" => _, "version" => "2.0.0"},
                                          %{"id" => _, "version" => "1.0.0"}],
                           "relay_groups" => [],
                           "inserted_at" => _,
                           "updated_at" => _}} = json_response(conn, 200)
  end

  test "shows enabled bundle", %{authed: requestor} do
    {:ok, _version3} = Bundles.install(%{"name" => "foo", "version" => "3.0.0", "config_file" => %{}})
    {:ok, version2}  = Bundles.install(%{"name" => "foo", "version" => "2.0.0", "config_file" => %{
                                          "permissions" => ["foo:bar"],
                                          "commands" => %{"blah" => %{}}}})
    {:ok, version1}  = Bundles.install(%{"name" => "foo", "version" => "1.0.0", "config_file" => %{}})

    :ok = Bundles.set_bundle_version_status(version2, :enabled)
    bundle = version1.bundle

    relay_group = relay_group("test-group")
    relay = relay("test-relay", "seekrit_token")
    add_relay_to_group(relay_group.id, relay.id)
    assign_bundle_to_group(relay_group.id, bundle.id)

    conn = api_request(requestor, :get, "/v1/bundles/#{bundle.id}")

    bundle_id = bundle.id
    bundle_name = bundle.name
    relay_group_id = relay_group.id
    relay_group_name = relay_group.name

    version_id = version2.id
    assert %{"bundle" => %{"id" => ^bundle_id,
                           "name" => ^bundle_name,
                           "enabled_version" => %{"id" => ^version_id,
                                                  "version" => "2.0.0",
                                                  "name" => "foo",
                                                  "permissions" => [%{"id" => _,
                                                                      "bundle" => "foo",
                                                                      "name" => "bar"}],
                                                  "commands" => [%{"bundle" => "foo",
                                                                   "name" => "blah"}]},
                           "versions" => [%{"id" => _, "version" => "3.0.0"},
                                          %{"id" => _, "version" => "2.0.0"},
                                          %{"id" => _, "version" => "1.0.0"}],
                           "relay_groups" => [%{"id" => ^relay_group_id,
                                                "name" => ^relay_group_name}],
                           "inserted_at" => _,
                           "updated_at" => _}} = json_response(conn, 200)
  end

  test "cannot view bundle that doesn't exist", %{authed: requestor} do
    conn = api_request(requestor, :get, "/v1/bundles/#{@bad_uuid}")
    assert "Bundle #{@bad_uuid} not found" = json_response(conn, 404)["error"]
  end

  test "cannot view bundle without permission", %{unauthed: requestor} do
    bundle = bundle_version("test-1").bundle
    conn = api_request(requestor, :get, "/v1/bundles/#{bundle.id}")
    assert conn.halted
    assert conn.status == 403
  end

  test "cannot delete the embedded bundle", %{authed: requestor} do
    bundle = Bundles.active_embedded_bundle_version().bundle
    conn = api_request(requestor, :delete, "/v1/bundles/#{bundle.id}")
    assert "Cannot delete operable bundle" == json_response(conn, 403)["error"]
  end

  test "cannot delete the site bundle", %{authed: requestor} do
    bundle = Bundles.site_bundle_version().bundle
    conn = api_request(requestor, :delete, "/v1/bundles/#{bundle.id}")
    assert "Cannot delete site bundle" == json_response(conn, 403)["error"]
  end

  test "cannot delete a bundle with an enabled version", %{authed: requestor} do
    version = bundle_version("test-1")
    :ok = Bundles.set_bundle_version_status(version, :enabled)

    conn = api_request(requestor, :delete, "/v1/bundles/#{version.bundle.id}")
    assert "Cannot delete test-1 bundle, because version 0.1.0 is currently enabled" = json_response(conn, 403)["error"]
  end

  test "can delete a bundle without an enabled version", %{authed: requestor} do
    version = bundle_version("test-1")

    conn = api_request(requestor, :delete, "/v1/bundles/#{version.bundle.id}")
    assert response(conn, 204)
  end

  test "can't delete a bundle without permission", %{unauthed: requestor} do
    version = bundle_version("test-1")

    conn = api_request(requestor, :delete, "/v1/bundles/#{version.bundle.id}")
    assert conn.halted
    assert conn.status == 403
  end

  test "cannot delete bundle that doesn't exist", %{authed: requestor} do
    conn = api_request(requestor, :delete, "/v1/bundles/#{@bad_uuid}")
    assert "Bundle #{@bad_uuid} not found" = json_response(conn, 404)["error"]
  end

  test "show bundles", %{authed: requestor} do
    bundle_version("test-1")
    conn = api_request(requestor, :get, "/v1/bundles/")

    version = Application.fetch_env!(:cog, :embedded_bundle_version)

    assert %{"bundles" => [%{"id" => _,
                             "name" => "operable",
                             "enabled_version" => %{"version" => ^version},
                             "relay_groups" => [], # embedded bundle isn't in relay groups
                             "versions" => [%{"id" => _, "version" => ^version}]}, # only one, and it's the enabled one
                           %{"id" => _,
                             "name" => "test-1",
                             "enabled_version" => nil,
                             "relay_groups" => [],
                             "versions" => [%{"id" => _, "version" => "0.1.0"}]}]} = json_response(conn, 200)
  end

  test "cannot show bundles without permission", %{unauthed: requestor} do
    conn = api_request(requestor, :get, "/v1/bundles")
    assert conn.halted
    assert conn.status == 403
  end

  test "shows bundle versions", %{authed: requestor} do
    {:ok, version1}  = Bundles.install(%{"name" => "foo", "version" => "1.0.0", "config_file" => %{}})
    {:ok, _version2}  = Bundles.install(%{"name" => "foo", "version" => "2.0.0", "config_file" => %{
                                          "permissions" => ["foo:bar"],
                                          "commands" => %{"blah" => %{}}}})
    {:ok, _version3} = Bundles.install(%{"name" => "foo", "version" => "3.0.0", "config_file" => %{}})

    conn = api_request(requestor, :get, "/v1/bundles/#{version1.bundle.id}/versions")

    assert %{"bundle_versions" => [%{"commands" => [],
                                     "id" => _,
                                     "inserted_at" => _,
                                     "name" => "foo",
                                     "permissions" => [],
                                     "updated_at" => _,
                                     "version" => "1.0.0",
                                     "enabled" => false},
                                   %{"commands" => [%{"bundle" => "foo",
                                                      "name" => "blah"}],
                                     "id" => _,
                                     "inserted_at" => _,
                                     "name" => "foo",
                                     "permissions" => [%{"id" => _,
                                                         "bundle" => "foo",
                                                         "name" => "bar"}],
                                     "updated_at" => _,
                                     "version" => "2.0.0",
                                     "enabled" => false},
                                   %{"commands" => [],
                                     "id" => _,
                                     "inserted_at" => _,
                                     "name" => "foo",
                                     "permissions" => [],
                                     "updated_at" => _,
                                     "version" => "3.0.0",
                                     "enabled" => false}]} = json_response(conn, 200)
  end

  test "cannot show versions without permission", %{unauthed: requestor} do
    bundle = Bundles.active_embedded_bundle_version().bundle
    conn = api_request(requestor, :get, "/v1/bundles/#{bundle.id}/versions")

    assert conn.halted
    assert conn.status == 403
  end

  test "cannot show bundle versions for a bundle that doesn't exist", %{authed: requestor} do
    conn = api_request(requestor, :get, "/v1/bundles/#{@bad_uuid}/versions")
    assert "Bundle #{@bad_uuid} not found" = json_response(conn, 404)["error"]
  end


  ########################################################################

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
  defp config(:map),
    do: Spanner.Config.Parser.read_from_string!(config())
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
    cog_bundle_version: 3

    name: test_bundle
    version: "0.1.0"
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
      date:
        slack: "{{date}}"
    """
  end

  defp old_config do
    """
    ---
    # Format version
    cog_bundle_version: 2

    name: test_bundle
    version: "0.1.0"
    permissions:
    - test_bundle:date
    - test_bundle:time
    docker:
      image: operable-bundle/test_bundle
      tag: v0.1.0
    commands:
      date:
        executable: /usr/local/bin/date
        enforcing: false
        options:
          option1:
            type: string
            description: An option
            required: false
            short_flag: o
      time:
        executable: /usr/local/bin/time
        rules:
        - when command is test_bundle:time must have test_bundle:time
    templates:
      time:
        slack: "{{time}}"
      date:
        slack: "{{date}}"
    """
  end

end
