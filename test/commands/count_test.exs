defmodule Cog.Test.Commands.CountTest do
  use Cog.CommandCase, command_module: Cog.Commands.Count

  test "basic count" do
    inv_id = "basic_count"
    memory_accum(inv_id, %{"a" => 1})
    memory_accum(inv_id, %{"b" => 3})

    response = new_req(invocation_id: inv_id, cog_env: %{"a" => 2})
               |> send_req()
               |> unwrap()

    assert(response == 3)
  end

  test "count by simple key" do
    inv_id = "simple_key_count"
    memory_accum(inv_id, %{"a" => 1})
    memory_accum(inv_id, %{"b" => 3})

    response = new_req(invocation_id: inv_id, cog_env: %{"a" => 2}, args: ["a"])
               |> send_req()
               |> unwrap()

    assert(response == 2)
  end

  test "count by complex key" do
    inv_id = "complex_key_count"
    memory_accum(inv_id, %{"a" => %{"b" => 1}})
    memory_accum(inv_id, %{"a" => %{"b" => 3}})

    response = new_req(invocation_id: inv_id, cog_env: %{"a" => %{"c" => 2}}, args: ["a.b"])
               |> send_req()
               |> unwrap()

    assert(response == 2)
  end

  test "count by incorrect key" do
    inv_id = "complex_incorrect"
    memory_accum(inv_id, %{"a" => %{"b" => 1}})
    memory_accum(inv_id, %{"a" => %{"b" => 3}})

    response = new_req(invocation_id: inv_id, cog_env: %{"a" => %{"c" => 2}}, args: ["c.d"])
               |> send_req()
               |> unwrap()

    assert(response == 0)
  end

  test "count of nothing" do
    inv_id = "complex_nothing"

    response = new_req(invocation_id: inv_id, cog_env: %{}, args: [])
               |> send_req()
               |> unwrap()

    assert(response == 0)
  end
end
