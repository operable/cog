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

  test "cannot view bundle without permission", %{unauthed: requestor} do
    bundle = bundle("test-1")
    conn = api_request(requestor, :get, "/v1/bundles/#{bundle.id}")
    assert conn.halted
    assert conn.status == 403
  end

end
