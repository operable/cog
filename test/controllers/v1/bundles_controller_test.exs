defmodule Cog.V1.BundlesControllerTest do
  alias Ecto.DateTime

  require Logger

  use Cog.ModelCase
  use Cog.ConnCase

  alias Cog.Repository.Bundles

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

  test "shows disabled bundle", %{authed: requestor} do
    {:ok, _version3} = Bundles.install(%{"name" => "foo", "version" => "3.0.0", "config_file" => %{}})
    {:ok, _version2} = Bundles.install(%{"name" => "foo", "version" => "2.0.0", "config_file" => %{}})
    {:ok, version1} = Bundles.install(%{"name" => "foo", "version" => "1.0.0", "config_file" => %{}})

    bundle = version1.bundle

    conn = api_request(requestor, :get, "/v1/bundles/#{bundle.id}")
    assert %{"bundle" => %{"id" => bundle.id,
                           "name" => bundle.name,
                           "versions" => ["1.0.0", "2.0.0", "3.0.0"],
                           "relay_groups" => [],
                           "inserted_at" => "#{DateTime.to_iso8601(bundle.inserted_at)}",
                           "updated_at" => "#{DateTime.to_iso8601(bundle.updated_at)}"}} == json_response(conn, 200)
  end

  test "shows enabled bundle", %{authed: requestor} do
    {:ok, _version3} = Bundles.install(%{"name" => "foo", "version" => "3.0.0", "config_file" => %{}})
    {:ok, version2} = Bundles.install(%{"name" => "foo", "version" => "2.0.0", "config_file" => %{}})
    {:ok, version1} = Bundles.install(%{"name" => "foo", "version" => "1.0.0", "config_file" => %{}})

    :ok = Bundles.set_bundle_version_status(version2, :enabled)
    bundle = version1.bundle

    conn = api_request(requestor, :get, "/v1/bundles/#{bundle.id}")
    assert %{"bundle" => %{"id" => bundle.id,
                           "name" => bundle.name,
                           "enabled_version" => "2.0.0",
                           "versions" => ["1.0.0", "2.0.0", "3.0.0"],
                           "relay_groups" => [],
                           "inserted_at" => "#{DateTime.to_iso8601(bundle.inserted_at)}",
                           "updated_at" => "#{DateTime.to_iso8601(bundle.updated_at)}"}} == json_response(conn, 200)
  end

  test "cannot view bundle without permission", %{unauthed: requestor} do
    bundle = bundle_version("test-1").bundle
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
        hipchat: "{{time}}"
      date:
        slack: "{{date}}"
        hipchat: "{{date}}"
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
        hipchat: "{{time}}"
      date:
        slack: "{{date}}"
        hipchat: "{{date}}"
    """
  end

end
