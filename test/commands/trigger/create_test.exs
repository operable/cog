defmodule Cog.Test.Commands.Trigger.CreateTest do
  use Cog.CommandCase, command_module: Cog.Commands.Trigger.Create

  import Cog.Support.ModelUtilities, only: [user: 1]

  test "creating a trigger (simple)" do
    {:ok, payload} = new_req(args: ["foo", "echo stuff"])
    |> send_req()

    assert %{id: _,
             name: "foo",
             pipeline: "echo stuff",
             enabled: true,
             as_user: nil,
             description: nil,
             invocation_url: _,
             timeout_sec: 30} = payload
  end

  test "creating a trigger (complex)" do
    user("bobby_tables")
    {:ok, payload} = new_req(args: ["foo", "echo stuff"],
                             options: %{"description" => "behold, a trigger",
                                        "enabled" => false,
                                        "as-user" => "bobby_tables",
                                        "timeout-sec" => 100})
    |> send_req()

    assert %{id: _,
             name: "foo",
             pipeline: "echo stuff",
             enabled: false,
             as_user: "bobby_tables",
             description: "behold, a trigger",
             invocation_url: _,
             timeout_sec: 100} = payload
  end

  test "creating a trigger with an invalid timeout fails" do
    {:error, error} = new_req(args: ["foo", "echo stuff"],
                              options: %{"timeout-sec" => 0})
    |> send_req()

    assert(error == "timeout_sec must be greater than 0")
  end


end
