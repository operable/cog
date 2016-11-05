defmodule Cog.Test.Commands.SleepTest do
  use Cog.CommandCase, command_module: Cog.Commands.Sleep

  test "basic sleeping" do
    request = fn ->
      new_req(cog_env: "foo", args: [3])
      |> send_req()
    end

    # We're running the command as a task so it doesn't block the test process
    task = Task.async(request)

    # First we yield with a short timeout to ensure that the command is sleeping
    assert(nil == Task.yield(task, 1000))

    # Then we yield again with a longer timeout to make sure something is returned
    # and the command didn't just crash.
    {:ok, task_response} = Task.yield(task, 3000)
    assert({:ok, ["foo"]} == task_response)
  end

  test "should NOT sleep if it's NOT the last invocation step" do

    Enum.each(["first", nil], fn(step) ->
      request = fn ->
        new_req(args: [5], invocation_step: step, invocation_id: "dont_sleep")
        |> send_req()
      end

      # We're running the command as a task so it doesn't block the test process
      response = Task.async(request)
      |> Task.yield(1000) # The task should not sleep, but in case it does, we'll set the timeout

      # The task should return before the timeout, so we shouldn't get nil this time
      refute(is_nil(response), "Slept on the #{step} invocation step.")
    end)

  end

  test "should accumulate data" do
    results = Enum.map(["first", nil, "last"], fn(step) ->
      new_req(cog_env: "foo", args: [0], invocation_step: step, invocation_id: "sleep_accum")
      |> send_req()
    end)

    assert([{:ok, nil},
            {:ok, nil},
            {:ok, ["foo", "foo", "foo"]}] == results)
  end

end
