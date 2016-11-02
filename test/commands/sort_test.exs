defmodule Cog.Test.Commands.SortTest do
  use Cog.CommandCase, command_module: Cog.Commands.Sort

  setup do
    seed = [%{"a" => 1},
            %{"a" => 3},
            %{"a" => 2}]

    {:ok, %{seed: seed}}
  end

  test "basic sorting", %{seed: seed} do
    request = Enum.map(seed, &(new_req(cog_env: &1)))

    # When you send a list of requests you get a list of responses back
    # We only care about the last one though, the rest should be nil
    {:ok, response} = send_req(request) |> List.last

    decoded = Poison.decode!(response)
    assert [%{"a" => 1},
            %{"a" => 2},
            %{"a" => 3}] = decoded
  end

  test "sorting in descending order", %{seed: seed} do
    request = Enum.map(seed, &(new_req(cog_env: &1, options: %{"desc" => true})))

    {:ok, response} = send_req(request) |> List.last

    decoded = Poison.decode!(response)
    assert [%{"a" => 3},
            %{"a" => 2},
            %{"a" => 1}] = decoded
  end

  test "sorting by specific fields" do
    seed = [%{"a" => 3, "b" => 4},
            %{"a" => 1, "b" => 4},
            %{"a" => 2, "b" => 6}]
    request = Enum.map(seed, &(new_req(cog_env: &1, args: ["b", "a"])))

    {:ok, response} = send_req(request) |> List.last

    decoded = Poison.decode!(response)
    assert [%{"a" => 1, "b" => 4},
            %{"a" => 3, "b" => 4},
            %{"a" => 2, "b" => 6}] = decoded
  end
end
