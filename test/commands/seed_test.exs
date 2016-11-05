defmodule Cog.Test.Commands.SeedTest do
  use Cog.CommandCase, command_module: Cog.Commands.Seed

  test "basic seeding" do
    {:ok, response} = new_req(args: [~s([{"a": 1}, {"a": 3}, {"a": 2}])])
    |> send_req()

    assert([%{a: 1}, %{a: 3}, %{a: 2}] == response)
  end

end
