defmodule Cog.V1.DynamicConfigControllerTest do

  require Logger

  use Cog.ModelCase
  use Cog.ConnCase

  alias Cog.Repository.Bundles

  setup do
    # Requests handled by the dynamic config controller require this permission
    required_permission = permission("#{Cog.embedded_bundle}:manage_commands")

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

  test "request missing dynamic config returns 404", %{authed: requestor, bundle: bundle} do
    conn = api_request(requestor, :get, "/v1/bundles/#{bundle.id}/dynamic_config")
    assert conn.status == 404
  end

  test "cannot add dynamic config without managed_commands permission", %{unauthed: requestor, bundle: bundle} do
    conn = api_request(requestor, :post, "/v1/bundles/#{bundle.id}/dynamic_config", body: %{"config": %{"test1" => "abc"}})
    assert conn.halted
    assert conn.status == 403
  end

  test "write dynamic config", %{authed: requestor, bundle: bundle} do
    conn = api_request(requestor, :post, "/v1/bundles/#{bundle.id}/dynamic_config", body: %{"config": %{"test1" => "abc"}})
    assert conn.status == 201
    conn = api_request(requestor, :get, "/v1/bundles/#{bundle.id}/dynamic_config")
    assert conn.status == 200
    body = Poison.decode!(conn.resp_body)
    assert Map.has_key?(body, "dynamic_configuration")
    config = Map.get(body, "dynamic_configuration")
    assert Map.equal?(config, %{"bundle_name" => bundle.name,
                                "bundle_id" => bundle.id,
                                "config" => %{"test1" => "abc"}})
  end

  test "overwrite dynamic config", %{authed: requestor, bundle: bundle} do
    conn = api_request(requestor, :post, "/v1/bundles/#{bundle.id}/dynamic_config", body: %{"config": %{"test1" => "abc"}})
    assert conn.status == 201
    conn = api_request(requestor, :get, "/v1/bundles/#{bundle.id}/dynamic_config")
    assert conn.status == 200
    body = Poison.decode!(conn.resp_body)
    config = Map.fetch!(body, "dynamic_configuration")
    assert Map.equal?(config, %{"bundle_name" => bundle.name,
                                "bundle_id" => bundle.id,
                                "config" => %{"test1" => "abc"}})
    conn = api_request(requestor, :post, "/v1/bundles/#{bundle.id}/dynamic_config", body: %{"config": %{"test1" => "abc", "test2" => [1,2,3]}})
    assert conn.status == 201
    conn = api_request(requestor, :get, "/v1/bundles/#{bundle.id}/dynamic_config")
    assert conn.status == 200
    body = Poison.decode!(conn.resp_body)
    config = Map.fetch!(body, "dynamic_configuration")
    Logger.debug("#{inspect config}")
    assert Map.equal?(config, %{"bundle_name" => bundle.name,
                                "bundle_id" => bundle.id,
                                "config" => %{"test1" => "abc", "test2" => [1,2,3]}})
  end

  test "cannot request existing dynamic config without manage_commands permission", %{authed: authed, unauthed: unauthed, bundle: bundle} do
    conn = api_request(authed, :post, "/v1/bundles/#{bundle.id}/dynamic_config", body: %{"config": %{"test1" => "abc"}})
    assert conn.status == 201
    conn = api_request(authed, :get, "/v1/bundles/#{bundle.id}/dynamic_config")
    assert conn.status == 200
    body = Poison.decode!(conn.resp_body)
    config = Map.fetch!(body, "dynamic_configuration")
    assert Map.equal?(config, %{"bundle_name" => bundle.name,
                                "bundle_id" => bundle.id,
                                "config" => %{"test1" => "abc"}})
    conn = api_request(unauthed, :get, "/v1/bundles/#{bundle.id}/dynamic_config")
    assert conn.status == 403
  end

  test "delete missing dynamic config returns 404", %{authed: requestor, bundle: bundle} do
    conn = api_request(requestor, :delete, "/v1/bundles/#{bundle.id}/dynamic_config")
    assert conn.status == 404
  end

  test "must have manage_commands permission to delete dynamic config", %{unauthed: requestor, bundle: bundle} do
    conn = api_request(requestor, :delete, "/v1/bundles/#{bundle.id}/dynamic_config")
    assert conn.status == 403
  end

  test "delete dynamic config", %{authed: requestor, bundle: bundle} do
    conn = api_request(requestor, :post, "/v1/bundles/#{bundle.id}/dynamic_config", body: %{"config": %{"test1" => "abc"}})
    assert conn.status == 201
    conn = api_request(requestor, :delete, "/v1/bundles/#{bundle.id}/dynamic_config")
    assert conn.status == 204
    conn = api_request(requestor, :get, "/v1/bundles/#{bundle.id}/dynamic_config")
    assert conn.status == 404
  end

  test "must have manage_commands permission to delete existing dynamic config", %{unauthed: unauthed, authed: authed, bundle: bundle} do
    conn = api_request(authed, :post, "/v1/bundles/#{bundle.id}/dynamic_config", body: %{"config": %{"test1" => "abc"}})
    assert conn.status == 201
    conn = api_request(unauthed, :delete, "/v1/bundles/#{bundle.id}/dynamic_config")
    assert conn.status == 403
  end

end
