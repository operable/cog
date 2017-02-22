defmodule Cog.Test.Pipeline.KillTest do
  use Cog.CommandCase, command_module: Cog.Commands.Pipeline.Kill,
                       command_tag: "pipeline_kill"

  alias Cog.Repository.PipelineHistory
  import Cog.Support.ModelUtilities, only: [user: 1,
                                            with_permission: 2]

  setup do
    user = user("pipelineuser")
    other_user = user("otherpipelineuser")
    admin_user = user("adminpipelineuser")
                 |> with_permission("operable:manage_user_pipeline")

    {:ok, task} = Task.start_link(fn -> Process.sleep(:infinity) end)

    pipeline = PipelineHistory.new(%{id: "fakeid",
                                     text: "Some text",
                                     room_name: "FakeRoom",
                                     room_id: "fakeroomid",
                                     provider: "test",
                                     count: 1,
                                     pid: task,
                                     state: "running",
                                     user_id: user.id})

    {:ok, %{user: user,
            other_user: other_user,
            admin_user: admin_user,
            pipeline: pipeline}}
  end

  test "a user can kill their own pipeline",
    %{user: user, pipeline: pipeline} do

      response = new_req(args: [pipeline.id], user: user)
                 |> send_req()
                 |> unwrap()

      assert(%{killed: ["fakeid"],
               killed_text: "fakeid"} = response)
  end

  test "a user cannot kill other user's pipelines",
    %{other_user: other_user, pipeline: pipeline} do

      response = new_req(args: [pipeline.id], user: other_user)
                 |> send_req()
                 |> unwrap()

      assert(%{killed: [], killed_text: "none"} = response)
  end

  test "a user can kill othe user's pipelines with the correct permission",
    %{admin_user: admin_user, pipeline: pipeline} do

      response = new_req(args: [pipeline.id], user: admin_user)
                 |> send_req()
                 |> unwrap()

      assert(%{killed: ["fakeid"],
               killed_text: "fakeid"} = response)
    end

end
