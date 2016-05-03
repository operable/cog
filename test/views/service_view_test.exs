defmodule Cog.V1.ServiceViewTest do
  use Cog.ConnCase, async: true
  import Phoenix.View

  setup do
    model = %{name: "memory",
              version: "1.0.0",
              api: %{}} # pretend that's swagger

    json = %{"name" => "memory",
                     "version" => "1.0.0",
                     "meta_url" => "http://localhost:4002/v1/services/meta/deployed/memory"}

    {:ok, %{model: model, json: json}}
  end

  test "renders index.json", %{model: model, json: json} do
    content = render_to_string(Cog.V1.ServiceView,
                               "index.json",
                               conn: conn(), services: [model])
    |> Poison.decode!

    assert %{"info" => %{"cog_version" => "0.5.0",
                         "cog_services_api_version" => "1",
                         "services" => [json]}} == content
  end

  test "renders show.json", %{model: model, json: json} do
    content = render_to_string(Cog.V1.ServiceView,
                               "show.json",
                               conn: conn(), service: model)
    |> Poison.decode!

    assert %{"service" => json} == content
  end

end
