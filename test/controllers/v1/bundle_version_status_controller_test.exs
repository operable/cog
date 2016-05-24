defmodule Cog.V1.BundleVersionStatusControllerTest do
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

  test "show status of embedded bundle version", %{authed: requestor} do
    version = Bundles.active_embedded_bundle_version
    {:ok, %Carrier.Credentials{id: relay_id}} = Carrier.CredentialManager.get()

    conn = api_request(requestor, :get, "/v1/bundles/#{version.bundle.id}/status")
    version = Application.spec(:cog, :vsn) |> IO.chardata_to_string

    assert %{"relays" => [relay_id],
             "name" => "operable",
             "enabled_version" => version,
             "enabled" => true} == json_response(conn, 200)
  end

  test "show status of non-enabled bundle", %{authed: requestor} do
    {:ok, version} = Bundles.install(%{"name" => "foo", "version" => "1.0.0", "config_file" => %{}})

    conn = api_request(requestor, :get, "/v1/bundles/#{version.bundle.id}/status")

    assert %{"relays" => [],
             "name" => "foo",
             "enabled" => false} == json_response(conn, 200)
  end

  test "showing status of non-existent bundle fails", %{authed: requestor} do
    conn = api_request(requestor, :get, "/v1/bundles/#{@bad_uuid}/status")
    assert "Bundle #{@bad_uuid} not found" == json_response(conn, 404)["error"]
  end

  test "setting status of non-existent bundle version fails", %{authed: requestor} do
    conn = api_request(requestor, :post,
                       "/v1/bundles/#{@bad_uuid}/versions/#{@bad_uuid2}/status",
                       body: %{status: "enabled"})
    assert "Bundle version #{@bad_uuid2} not found" == json_response(conn, 404)["error"]
  end

  test "setting status of embedded bundle version is not allowed", %{authed: requestor} do
    version = Bundles.active_embedded_bundle_version
    conn = api_request(requestor, :post,
                       "/v1/bundles/#{version.bundle.id}/versions/#{version.id}/status",
                       body: %{status: "enabled"})

    assert "Cannot modify the status of the operable bundle" = json_response(conn, 403)["error"]
  end

  test "setting status of site bundle version is not allowed", %{authed: requestor} do
    version = Bundles.site_bundle_version
    conn = api_request(requestor, :post,
                       "/v1/bundles/#{version.bundle.id}/versions/#{version.id}/status",
                       body: %{status: "enabled"})

    assert "Cannot modify the status of the site bundle" = json_response(conn, 403)["error"]
  end

  test "enabling a version works", %{authed: requestor} do
    {:ok, version} = Bundles.install(%{"name" => "foo", "version" => "1.0.0", "config_file" => %{}})

    conn = api_request(requestor, :post,
                       "/v1/bundles/#{version.bundle.id}/versions/#{version.id}/status",
                       body: %{status: "enabled"})

    assert %{"relays" => [],
             "name" => "foo",
             "enabled_version" => "1.0.0",
             "enabled" => true} == json_response(conn, 200)
  end

  test "disabling a version works", %{authed: requestor} do
    {:ok, version} = Bundles.install(%{"name" => "foo", "version" => "1.0.0", "config_file" => %{}})
    :ok = Bundles.set_bundle_version_status(version, :enabled)
    conn = api_request(requestor, :post,
                       "/v1/bundles/#{version.bundle.id}/versions/#{version.id}/status",
                       body: %{status: "disabled"})

    assert %{"relays" => [],
             "name" => "foo",
             "enabled" => false} == json_response(conn, 200)
  end

  test "changing status of a bundle requires permission", %{unauthed: requestor} do
    {:ok, version} = Bundles.install(%{"name" => "foo", "version" => "1.0.0", "config_file" => %{}})
    conn = api_request(requestor, :post,
                       "/v1/bundles/#{version.bundle.id}/versions/#{version.id}/status",
                       body: %{status: "enabled"})

    assert conn.halted
    assert conn.status == 403
  end

  test "viewing status of a bundle requires permission", %{unauthed: requestor} do
    {:ok, version} = Bundles.install(%{"name" => "foo", "version" => "1.0.0", "config_file" => %{}})
    conn = api_request(requestor, :get,
                       "/v1/bundles/#{version.bundle.id}/status")

    assert conn.halted
    assert conn.status == 403
  end

  test "setting an unrecognized status is an error", %{authed: requestor} do
    {:ok, version} = Bundles.install(%{"name" => "foo", "version" => "1.0.0", "config_file" => %{}})
    conn = api_request(requestor, :post,
                       "/v1/bundles/#{version.bundle.id}/versions/#{version.id}/status",
                       body: %{status: "doing-all-kinds-of-nifty-stuff"})

    assert "Unrecognized status: \"doing-all-kinds-of-nifty-stuff\"" == json_response(conn, 400)["error"]
  end

  test "omitting the status is an error", %{authed: requestor} do
    {:ok, version} = Bundles.install(%{"name" => "foo", "version" => "1.0.0", "config_file" => %{}})
    conn = api_request(requestor, :post,
                       "/v1/bundles/#{version.bundle.id}/versions/#{version.id}/status",
                       body: %{blah: "blah"})

    assert "Missing 'status'. Please specify 'enabled' or 'disabled'" == json_response(conn, 400)["error"]
  end

end
