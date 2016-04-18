defmodule Cog.V1.TriggerViewTest do
  use Cog.ConnCase, async: true
  import Phoenix.View

  alias Cog.Models.Trigger

  setup do
    uuid = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"

    model = %Trigger{id: uuid,
                       name: "echo",
                       as_user: "user",
                       pipeline: "echo foo",
                       timeout_sec: 30,
                       enabled: true,
                       description: "Something really awesome"}
    json = %{"id" => uuid,
             "name" => "echo",
             "as_user" => "user",
             "pipeline" => "echo foo",
             "timeout_sec" => 30,
             "enabled" => true,
             "description" => "Something really awesome",
             "invocation_url" => "http://localhost:4001/v1/triggers/#{uuid}"}
    {:ok, %{model: model, json: json}}
  end

  test "renders trigger.json", %{model: model, json: json} do
    content = render_to_string(Cog.V1.TriggerView,
                               "trigger.json",
                               conn: conn(), trigger: model)
    |> Poison.decode!
    assert json == content
  end

  test "renders index.json", %{model: model, json: json} do
    content = render_to_string(Cog.V1.TriggerView,
                               "index.json",
                               conn: conn(), triggers: [model])
    |> Poison.decode!

    assert %{"triggers" => [json]} == content
  end

  test "renders show.json", %{model: model, json: json} do
    content = render_to_string(Cog.V1.TriggerView,
                               "show.json",
                               conn: conn(), trigger: model)
    |> Poison.decode!

    assert %{"trigger" => json} == content
  end

end
