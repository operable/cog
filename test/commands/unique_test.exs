defmodule Cog.Test.Commands.UniqueTest do
  use Cog.CommandCase, command_module: Cog.Commands.Unique

  test "basic uniquing" do
    inv_id = "basic_uniquing"
    memory_accum(inv_id, %{"a" => 1})
    memory_accum(inv_id, %{"a" => 3})

    response = new_req(cog_env: %{"a" => 1}, invocation_id: inv_id)
               |> send_req()
               |> unwrap()

    assert([%{a: 1}, %{a: 3}] == response)
  end
end
