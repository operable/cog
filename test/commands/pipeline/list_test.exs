defmodule Cog.Test.Pipeline.ListTest do
  use Cog.CommandCase, command_module: Cog.Commands.Pipeline.List,
                       command_tag: "pipeline_list"

  alias Cog.Repository.PipelineHistory
  import Cog.Support.ModelUtilities, only: [user: 1,
                                            with_permission: 2]

  setup do
    user = user("pipelineuser")
    other_user = user("otherpipelineuser")
    admin_user = user("adminpipelineuser")
                 |> with_permission("operable:manage_user_pipeline")

    for n <- 1..5 do
      PipelineHistory.new(%{id: "fakeid#{n}",
                            text: "Some text",
                            room_name: "FakeRoom",
                            room_id: "fakeroomid",
                            provider: "test",
                            count: n,
                            state: "running",
                            user_id: user.id})
    end

    {:ok, %{user: user, other_user: other_user, admin_user: admin_user}}
  end

  test "listing pipelines", %{user: user} do
    response = new_req(user: user)
               |> send_req()
               |> unwrap()

    assert(%{pipeline_count: 5,
             pipelines: [%{id: "fakeid5"},
                         %{id: "fakeid4"},
                         %{id: "fakeid3"},
                         %{id: "fakeid2"},
                         %{id: "fakeid1"}]} = response)
  end

  test "Can't list other user's pipelines without permission",
        %{user: user, other_user: other_user} do

    response = new_req(options: %{"user" => user.username}, user: other_user)
               |> send_req()
               |> unwrap_error()

    assert("You must have the operable:manage_user_pipeline permission to view pipeline history for other users." = response)
  end

  test "Can list other user's pipelines with permission", %{user: user, admin_user: admin_user} do
    response = new_req(options: %{"user" => user.username}, user: admin_user)
               |> send_req()
               |> unwrap()

    assert(%{pipeline_count: 5,
             pipelines: [%{id: "fakeid5"},
                         %{id: "fakeid4"},
                         %{id: "fakeid3"},
                         %{id: "fakeid2"},
                         %{id: "fakeid1"}]} = response)
  end
end
