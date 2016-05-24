defmodule Cog.V1.BundleVersionControllerTest do
  require Logger

  use Cog.ModelCase
  use Cog.ConnCase

  alias Cog.Repository.Bundles

  @bad_uuid "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
  @bad_uuid2 "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeee1"

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

  test "cannot show a version without permission", %{unauthed: requestor} do
    version = Bundles.active_embedded_bundle_version
    conn = api_request(requestor, :get,
                       "/v1/bundles/#{version.bundle.id}/versions/#{version.id}")
    assert conn.halted
    assert conn.status == 403
  end

  test "cannot view bundle version that doesn't exist", %{authed: requestor} do
    conn = api_request(requestor, :get, "/v1/bundles/#{@bad_uuid}/versions/#{@bad_uuid2}")
    assert "Bundle version #{@bad_uuid2} not found" = json_response(conn, 404)["error"]
  end

  test "show a bundle version", %{authed: requestor} do
    {:ok, version} = Bundles.install(%{"name" => "test-bundle",
                                       "version" => "1.0.0",
                                       "config_file" => %{
                                         "name" => "test-bundle",
                                         "version" => "1.0.0",
                                         "commands" => %{"foo" => %{},
                                                         "bar" => %{}},
                                         "permissions" => ["test-bundle:permission"]
                                       }})

    conn = api_request(requestor, :get,
                       "/v1/bundles/#{version.bundle.id}/versions/#{version.id}")

    assert %{"bundle_version" =>
              %{"id" => _,
                "name" => "test-bundle",
                "version" => "1.0.0",
                "inserted_at" => _,
                "updated_at" => _,
                "commands" => ["test-bundle:bar", "test-bundle:foo"],
                "permissions" => [%{"id" => _,
                                    "bundle" => "test-bundle",
                                    "name" => "permission"}]}} = json_response(conn, 200)
  end

  test "cannot delete an enabled bundle version", %{authed: requestor} do
    version = bundle_version("test-1")
    :ok = Bundles.set_bundle_version_status(version, :enabled)

    conn = api_request(requestor, :delete, "/v1/bundles/#{version.bundle.id}/versions/#{version.id}")
    assert "Cannot delete test-1 0.1.0, because it is currently enabled" = json_response(conn, 403)["error"]
  end

  test "cannot delete the embedded bundle version", %{authed: requestor} do
    version = Bundles.active_embedded_bundle_version()
    conn = api_request(requestor, :delete, "/v1/bundles/#{version.bundle.id}/versions/#{version.id}")
    assert "Cannot delete operable bundle version" == json_response(conn, 403)["error"]
  end

  test "cannot delete the site bundle version", %{authed: requestor} do
    version = Bundles.site_bundle_version
    conn = api_request(requestor, :delete, "/v1/bundles/#{version.bundle.id}/versions/#{version.id}")
    assert "Cannot delete site bundle version" == json_response(conn, 403)["error"]
  end

  test "cannot delete bundle version that doesn't exist", %{authed: requestor} do
    conn = api_request(requestor, :delete, "/v1/bundles/#{@bad_uuid}/versions/#{@bad_uuid2}")
    assert "Bundle version #{@bad_uuid2} not found" = json_response(conn, 404)["error"]
  end

  test "can delete a disaled bundle version", %{authed: requestor} do
    {:ok, version} = Bundles.install(%{"name" => "test-bundle",
                                       "version" => "1.0.0",
                                       "config_file" => %{}})

    conn = api_request(requestor, :delete,
                       "/v1/bundles/#{version.bundle.id}/versions/#{version.id}")

    assert "" = response(conn, 204)
  end

  test "cannot delete a version without permission", %{unauthed: requestor} do
    {:ok, version} = Bundles.install(%{"name" => "test-bundle",
                                       "version" => "1.0.0",
                                       "config_file" => %{}})

    conn = api_request(requestor, :delete,
                       "/v1/bundles/#{version.bundle.id}/versions/#{version.id}")
    assert conn.halted
    assert conn.status == 403
  end

end
