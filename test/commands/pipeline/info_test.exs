defmodule Cog.Test.Pipeline.InfoTest do
  use Cog.CommandCase, command_module: Cog.Commands.Pipeline.Info,
                       command_tag: "pipeline_info"

  alias Cog.Repository.PipelineHistory
  import Cog.Support.ModelUtilities, only: [user: 1,
                                            with_permission: 2]

  setup do
    user = user("pipelineuser")
    other_user = user("otherpipelineuser")
    admin_user = user("adminpipelineuser")
                 |> with_permission("operable:manage_user_pipeline")

    pipeline = PipelineHistory.new(%{id: "fakeid",
                                     text: "Some text",
                                     room_name: "FakeRoom",
                                     room_id: "fakeroomid",
                                     provider: "test",
                                     count: 1,
                                     state: "running",
                                     user_id: user.id})

    {:ok, %{user: user,
            other_user: other_user,
            admin_user: admin_user,
            pipeline: pipeline}}
  end

  test "pipeline info", %{user: user, pipeline: pipeline} do
    response = new_req(args: [pipeline.id], user: user)
               |> send_req()
               |> unwrap()

    assert([%{id: "fakeid",
              room: "FakeRoom",
              state: "running",
              text: "Some text",
              user: "pipelineuser"}] = response)
  end

  test "other user can't see pipeline info without permission",
        %{other_user: other_user,
          pipeline: pipeline} do

    response = new_req(args: [pipeline.id], user: other_user)
               |> send_req()
               |> unwrap()

    assert([] = response)
  end

  test "can see pipeline info for other's pipelines with permission",
        %{admin_user: admin_user,
          pipeline: pipeline} do

    response = new_req(args: [pipeline.id], user: admin_user)
               |> send_req()
               |> unwrap()

    assert([%{id: "fakeid",
              room: "FakeRoom",
              state: "running",
              text: "Some text",
              user: "pipelineuser"}] = response)
  end
end
