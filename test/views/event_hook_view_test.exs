defmodule Cog.V1.EventHookViewTest do
  use Cog.ConnCase, async: true
  import Phoenix.View

  alias Cog.Models.EventHook

  setup do
    uuid = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"

    model = %EventHook{id: uuid,
                       name: "echo",
                       as_user: "user",
                       pipeline: "echo foo",
                       timeout_sec: 30,
                       active: true,
                       description: "Something really awesome"}
    json = %{"id" => uuid,
             "name" => "echo",
             "as_user" => "user",
             "pipeline" => "echo foo",
             "timeout_sec" => 30,
             "active" => true,
             "description" => "Something really awesome",
             "invocation_url" => "http://localhost:4001/v1/event_hooks/#{uuid}"}
    {:ok, %{model: model, json: json}}
  end

  test "renders hook.json", %{model: model, json: json} do
    content = render_to_string(Cog.V1.EventHookView,
                               "hook.json",
                               conn: conn(), event_hook: model)
    |> Poison.decode!
    assert json == content
  end

  test "renders index.json", %{model: model, json: json} do
    content = render_to_string(Cog.V1.EventHookView,
                               "index.json",
                               conn: conn(), event_hooks: [model])
    |> Poison.decode!

    assert %{"event_hooks" => [json]} == content
  end

  test "renders show.json", %{model: model, json: json} do
    content = render_to_string(Cog.V1.EventHookView,
                               "show.json",
                               conn: conn(), event_hook: model)
    |> Poison.decode!

    assert %{"event_hook" => json} == content
  end

end
