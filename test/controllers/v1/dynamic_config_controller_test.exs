defmodule Cog.V1.DynamicConfigControllerTest do

  require Logger

  use Cog.ModelCase
  use Cog.ConnCase

  alias Cog.Repository.Bundles

  setup do
    # Requests handled by the dynamic config controller require this permission
    required_permission = permission("#{Cog.Util.Misc.embedded_bundle}:manage_commands")

    # This user will be used to test the normal operation of the controller
    authed_user = user("cog")
    |> with_token
    |> with_permission(required_permission)

    # This user will be used to verify that the above permission is
    # indeed required for requests
    unauthed_user = user("sadpanda") |> with_token

    # Install a version so we have the bundle defined in the DB
    {:ok, _version} = Bundles.install(%{"name" => "super-bundle",
                                        "version" => "1.2.1",
                                        "config_file" => %{
                                          "name" => "super-bundle",
                                          "version" => "1.2.1",
                                          "commands" => %{"foo" => %{"documentation" => "docs for foo"},
                                                          "bar" => %{"documentation" => "docs for bar"}},
                                          "permissions" => ["super-bundle:permission"]}})
    bundle = Bundles.bundle_by_name("super-bundle")
    assert bundle != nil
    {:ok, %{bundle: bundle, authed: authed_user, unauthed: unauthed_user}}
  end

  test "cannot request dynamic config without manage_commands permission", %{unauthed: requestor, bundle: bundle} do
    conn = api_request(requestor, :get, "/v1/bundles/#{bundle.id}/dynamic_config")
    assert conn.halted
    assert conn.status == 403
  end

  test "cannot add dynamic config without managed_commands permission", %{unauthed: requestor, bundle: bundle} do
    conn = api_request(requestor, :post, "/v1/bundles/#{bundle.id}/dynamic_config/base", body: %{"config": %{"test1" => "abc"}})
    assert conn.halted
    assert conn.status == 403
  end

  test "write base dynamic config", %{authed: requestor, bundle: bundle} do
    conn = api_request(requestor, :post,
                       "/v1/bundles/#{bundle.id}/dynamic_config/base",
                       body: %{"config": %{"test1" => "abc"}})
    body = json_response(conn, 201)
    assert %{"dynamic_configuration" => %{
              "bundle_name" => bundle.name,
              "bundle_id" => bundle.id,
              "layer" => "base",
              "name" => "config",
              "config" => %{"test1" => "abc"}}} == body

    expected_location = "/v1/bundles/#{bundle.id}/dynamic_config/base"
    assert expected_location == redirected_to(conn, 201)
  end

  test "write room layer dynamic config", %{authed: requestor, bundle: bundle} do
    conn = api_request(requestor, :post,
                       "/v1/bundles/#{bundle.id}/dynamic_config/room/ops",
                       body: %{"config": %{"ops" => "4life"}})
    body = json_response(conn, 201)

    assert %{"dynamic_configuration" => %{
              "bundle_name" => bundle.name,
              "bundle_id" => bundle.id,
              "layer" => "room",
              "name" => "ops",
              "config" => %{"ops" => "4life"}}} == body

    expected_location = "/v1/bundles/#{bundle.id}/dynamic_config/room/ops"
    assert expected_location == redirected_to(conn, 201)
  end

  test "write user layer dynamic config", %{authed: requestor, bundle: bundle} do
    conn = api_request(requestor, :post,
                       "/v1/bundles/#{bundle.id}/dynamic_config/user/alice",
                       body: %{"config": %{"hello" => "world"}})
    body = json_response(conn, 201)
    assert %{"dynamic_configuration" => %{
              "bundle_name" => bundle.name,
              "bundle_id" => bundle.id,
              "layer" => "user",
              "name" => "alice",
              "config" => %{"hello" => "world"}}} == body

    expected_location = "/v1/bundles/#{bundle.id}/dynamic_config/user/alice"
    assert expected_location == redirected_to(conn, 201)
  end

  test "retrieve base dynamic config", %{authed: requestor, bundle: bundle} do
    set_config(bundle, "base", "config", %{"test1" => "abc"})

    conn = api_request(requestor, :get,
                       "/v1/bundles/#{bundle.id}/dynamic_config/base")
    body = json_response(conn, 200)
    assert %{"dynamic_configuration" => %{
              "bundle_name" => bundle.name,
              "bundle_id" => bundle.id,
              "layer" => "base",
              "name" => "config",
              "config" => %{"test1" => "abc"}}} == body

  end

  test "retrieve room layer dynamic config", %{authed: requestor, bundle: bundle} do
    set_config(bundle, "room", "ops", %{"ops" => "4life"})

    conn = api_request(requestor, :get,
                       "/v1/bundles/#{bundle.id}/dynamic_config/room/ops")
    body = json_response(conn, 200)
    assert %{"dynamic_configuration" => %{
              "bundle_name" => bundle.name,
              "bundle_id" => bundle.id,
              "layer" => "room",
              "name" => "ops",
              "config" => %{"ops" => "4life"}}} == body

  end

  test "retrieve user layer dynamic config", %{authed: requestor, bundle: bundle} do
    set_config(bundle, "user", "alice", %{"hello" => "world"})

    conn = api_request(requestor, :get,
                       "/v1/bundles/#{bundle.id}/dynamic_config/user/alice")
    body = json_response(conn, 200)
    assert %{"dynamic_configuration" => %{
              "bundle_name" => bundle.name,
              "bundle_id" => bundle.id,
              "layer" => "user",
              "name" => "alice",
              "config" => %{"hello" => "world"}}} == body
  end

  test "can't show a room config that doesn't exist", %{authed: requestor, bundle: bundle} do
    conn = api_request(requestor, :get, "/v1/bundles/#{bundle.id}/dynamic_config/room/foo")
    assert json_response(conn, 404)["error"]
  end

  test "can't show a user config that doesn't exist", %{authed: requestor, bundle: bundle} do
    conn = api_request(requestor, :get, "/v1/bundles/#{bundle.id}/dynamic_config/user/foo")
    assert json_response(conn, 404)["error"]
  end

  test "can't show just the room layer without also specifying a name", %{authed: requestor, bundle: bundle} do
    conn = api_request(requestor, :get, "/v1/bundles/#{bundle.id}/dynamic_config/room")
    assert json_response(conn, 404)["error"]
  end

  test "can't show just the user layer without also specifying a name", %{authed: requestor, bundle: bundle} do
    conn = api_request(requestor, :get, "/v1/bundles/#{bundle.id}/dynamic_config/user")
    assert json_response(conn, 404)["error"]
  end

  test "retrieve all configs for a bundle with no dynamic config set", %{authed: requestor, bundle: bundle} do
    conn = api_request(requestor, :get,
                       "/v1/bundles/#{bundle.id}/dynamic_config/")
    assert [] == json_response(conn, 200)["dynamic_configurations"]
  end

  test "retrieve all configs for a bundle with only the base layer set", %{authed: requestor, bundle: bundle} do
    set_config(bundle, "base", "config", %{"base" => "base"})

    conn = api_request(requestor, :get,
                       "/v1/bundles/#{bundle.id}/dynamic_config/")
    body = json_response(conn, 200)
    assert  %{"dynamic_configurations" => [%{
                                              "bundle_id" => bundle.id,
                                              "bundle_name" => bundle.name,
                                              "config" => %{"base" => "base"},
                                              "layer" => "base",
                                              "name" => "config"}]} == body
  end

  test "retrieve all configs for a bundle with only no base layer set", %{authed: requestor, bundle: bundle} do
    set_config(bundle, "user", "foo", %{"user" => "foo"})

    conn = api_request(requestor, :get,
                       "/v1/bundles/#{bundle.id}/dynamic_config/")
    body = json_response(conn, 200)
    assert  %{"dynamic_configurations" => [%{
                                              "bundle_id" => bundle.id,
                                              "bundle_name" => bundle.name,
                                              "config" => %{"user" => "foo"},
                                              "layer" => "user",
                                              "name" => "foo"}]} == body
  end


  test "retrieve all configs for a bundle with multiple layers set", %{authed: requestor, bundle: bundle} do
    set_config(bundle, "base", "config", %{"base" => "base"})
    set_config(bundle, "room", "ops", %{"room" => "ops"})
    set_config(bundle, "room", "dev", %{"room" => "dev"})
    set_config(bundle, "user", "bob", %{"user" => "bob"})
    set_config(bundle, "user", "alice", %{"user" => "alice"})

    conn = api_request(requestor, :get,
                       "/v1/bundles/#{bundle.id}/dynamic_config/")
    body = json_response(conn, 200)
    assert  %{"dynamic_configurations" => [%{"bundle_id" => bundle.id,
                                            "bundle_name" => bundle.name,
                                            "config" => %{"base" => "base"},
                                            "layer" => "base",
                                            "name" => "config"},
                                          %{"bundle_id" => bundle.id,
                                            "bundle_name" => bundle.name,
                                            "config" => %{"room" => "dev"},
                                            "layer" => "room",
                                            "name" => "dev"},
                                          %{"bundle_id" => bundle.id,
                                            "bundle_name" => bundle.name,
                                            "config" => %{"room" => "ops"},
                                            "layer" => "room",
                                            "name" => "ops"},
                                          %{"bundle_id" => bundle.id,
                                            "bundle_name" => bundle.name,
                                            "config" => %{"user" => "alice"},
                                            "layer" => "user",
                                            "name" => "alice"},
                                          %{"bundle_id" => bundle.id,
                                            "bundle_name" => bundle.name,
                                            "config" => %{"user" => "bob"},
                                            "layer" => "user",
                                            "name" => "bob"}]} == body
  end

  test "can't retrieve config for a bundle that doesn't exist", %{authed: requestor} do
    bad_uuid = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
    conn = api_request(requestor, :get, "/v1/bundles/#{bad_uuid}/dynamic_config/base")
    assert json_response(conn, 404)["error"]
  end

  test "can't save anything to a named base layer (there's only one base layer)", %{authed: requestor, bundle: bundle} do
    conn = api_request(requestor, :post,
                       "/v1/bundles/#{bundle.id}/dynamic_config/base/foo",
                       body: %{"config": %{"test1" => "abc"}})
    assert json_response(conn, 404)["error"]
  end

  test "can't save anything to an unrecognized layer", %{authed: requestor, bundle: bundle} do
    conn = api_request(requestor, :post,
                       "/v1/bundles/#{bundle.id}/dynamic_config/monkey/foo",
                       body: %{"config": %{"test1" => "abc"}})
    assert json_response(conn, 404)["error"]
  end

  test "overwrite dynamic config", %{authed: requestor, bundle: bundle} do
    set_config(bundle, "base", "config", %{"test1" => "abc"})

    conn = api_request(requestor, :post,
                       "/v1/bundles/#{bundle.id}/dynamic_config/base",
                       body: %{"config": %{"test1" => "abc", "test2" => [1,2,3]}})
    body = json_response(conn, 201)
    assert %{"dynamic_configuration" => %{
              "bundle_id" => bundle.id,
              "bundle_name" => bundle.name,
              "layer" => "base",
              "name" => "config",
              "config" => %{
                "test1" => "abc",
                "test2" => [1,2,3]
              }}} == body
  end

  test "must have manage_commands permission to delete dynamic config", %{unauthed: requestor, bundle: bundle} do
    conn = api_request(requestor, :delete, "/v1/bundles/#{bundle.id}/dynamic_config/base")
    assert conn.status == 403
  end

  test "delete base dynamic config", %{authed: requestor, bundle: bundle} do
    set_config(bundle, "base", "config", %{"test1" => "abc"})

    conn = api_request(requestor, :delete, "/v1/bundles/#{bundle.id}/dynamic_config/base")
    assert conn.status == 204

    refute Bundles.dynamic_config_for_bundle(bundle, "base", "config")
  end

  test "delete room dynamic config", %{authed: requestor, bundle: bundle} do
    set_config(bundle, "room", "ops", %{"test1" => "abc"})

    conn = api_request(requestor, :delete, "/v1/bundles/#{bundle.id}/dynamic_config/room/ops")
    assert conn.status == 204

    refute Bundles.dynamic_config_for_bundle(bundle, "room", "ops")
  end

  test "delete user dynamic config", %{authed: requestor, bundle: bundle} do
    set_config(bundle, "user", "alice", %{"test1" => "abc"})

    conn = api_request(requestor, :delete, "/v1/bundles/#{bundle.id}/dynamic_config/user/alice")
    assert conn.status == 204

    refute Bundles.dynamic_config_for_bundle(bundle, "user", "alice")
  end

  test "deleting non existent config", %{authed: requestor, bundle: bundle} do
    conn = api_request(requestor , :delete, "/v1/bundles/#{bundle.id}/dynamic_config/user/not_here")
    assert json_response(conn, 404)["error"]
  end

  ########################################################################

  defp set_config(bundle, layer, name, config) do
    {:ok, dynamic_config} = Bundles.create_dynamic_config_for_bundle!(bundle, %{"bundle_id" => bundle.id,
                                                                                "layer" => layer,
                                                                                "name" => name,
                                                                                "config" => config})
    dynamic_config
  end

end
