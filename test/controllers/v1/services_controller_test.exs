defmodule Cog.V1.ServicesControllerTest do
  use Cog.ConnCase

  @moduletag :services
  @endpoint Cog.ServiceEndpoint

  test "meta returns basic service metadata" do
    conn = get(build_conn(), "/v1/services/meta")
    assert %{"cog_services_api_version" => "1",
             "cog_version" => "0.5.0",
             "services" => _} = json_response(conn, 200)["info"]
  end

  test "meta returns info for deployed services" do
    # Not trying to validate the contents of the Swagger API docs,
    # just that it's swagger
    conn = get(build_conn(), "/v1/services/meta/deployed/memory")
    assert %{"name" => "memory",
             "version" => "1.0.0",
             "meta_url" => "http://localhost:4002/v1/services/meta/deployed/memory"} = json_response(conn, 200)["service"]
  end

  test "404 for metadata on non-deployed services" do
    conn = get(build_conn(), "/v1/services/meta/deployed/NOT_DEPLOYED")
    assert response(conn, 404)
  end
end
