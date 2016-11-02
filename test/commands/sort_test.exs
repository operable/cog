defmodule Cog.Test.Commands.SortTest do
  use Cog.CommandCase, command_module: Cog.Commands.Sort

  test "basic sorting" do
    # Add some items to the memory service
    inv_id = "basic_sorting_test_id"
    memory_accum(inv_id, %{a: 1})
    memory_accum(inv_id, %{a: 3})

    # Then we'll make our request with the last item
    # We don't have to set the invocation step here because by default `req/1`
    # sets it to "last".
    {:ok, response} = new_req(cog_env: %{a: 2}, invocation_id: inv_id)
    |> send_req()

    # Assert that things are in the proper order.
    assert [%{a: 1},
            %{a: 2},
            %{a: 3}] = response
  end

  test "sorting in descending order" do
    inv_id = "sorting_desc_test_id"
    memory_accum(inv_id, %{a: 1})
    memory_accum(inv_id, %{a: 3})

    {:ok, response} = new_req(cog_env: %{a: 2}, invocation_id: inv_id, options: %{"desc" => true})
    |> send_req()

    assert [%{a: 3},
            %{a: 2},
            %{a: 1}] = response
  end

  test "sorting by specific fields" do
    inv_id = "sorting_by_specific_field_test_id"
    memory_accum(inv_id, %{a: 3, b: 4})
    memory_accum(inv_id, %{a: 1, b: 4})

    {:ok, response} = new_req(cog_env: %{a: 2, b: 6}, invocation_id: inv_id, args: ["b", "a"])
    |> send_req()

    assert [%{a: 1, b: 4},
            %{a: 3, b: 4},
            %{a: 2, b: 6}] = response
  end

  test "as requests come in they are accumulated" do
    inv_id = "memory_service_sort_test"
    # The memory service encodes maps and stringifys the keys, so we have to
    # use the '=>' syntax.
    first_payload = %{"a" => 2}
    second_payload = %{"a" => 3}
    last_payload = %{"a" => 1}

    # Assert that we get nil back for our first request
    assert {:ok, nil} == new_req(cog_env: first_payload, invocation_step: "first", invocation_id: inv_id)
           |> send_req()

    # Assert that the correct value was stored
    assert [first_payload] == memory_fetch(inv_id)

    # Assert that we get nil back for our second request
    # Only the first and last invocation steps are set, the rest are nil.
    assert {:ok, nil} == new_req(cog_env: second_payload, invocation_step: nil, invocation_id: inv_id)
           |> send_req()

    # Assert that everything is accumulating properly
    assert [first_payload, second_payload] == memory_fetch(inv_id)

    # Our last request should return a result instead of nil
    # I'm setting the invocation_step to 'last' here for clarity, but the helper actually uses
    # 'last' as the default.
    refute {:ok, nil} == new_req(cog_env: last_payload, invocation_step: "last", invocation_id: inv_id)
           |> send_req()

    # Assert that the memory service contains no data
    assert %{"error" => "key not found"} == memory_fetch(inv_id)
  end
end
