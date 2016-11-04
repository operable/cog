defmodule Cog.Test.Commands.CatTest do
  use Cog.CommandCase, command_module: Cog.Commands.Cat

  alias Cog.Command.Service.DataStore

  @data_namespace [ "commands", "tee" ]

  setup :with_data

  test "cat returns data saved by tee" do
    response = new_req(args: ["test"])
               |> send_req()
               |> unwrap()

    assert(%{foo: "fooval"} = response)
  end

  test "cat -m merges input with saved content" do
    response = new_req(args: ["test"],
                       options: %{"merge" => true},
                       cog_env: %{"bar" => "barval"})
    |> send_req()
    |> unwrap()

    assert(%{foo: "fooval", bar: "barval"} = response)
  end

  test "cat -a append input to saved content" do
    response = new_req(args: ["test"],
                       options: %{"append" => true},
                       cog_env: %{"foo" => "fooval1"})
    |> send_req()
    |> unwrap()

    assert([%{foo: "fooval"},%{foo: "fooval1"}] = response)
  end


  ##### Setup functions #######

  defp with_data(_) do
    DataStore.replace(@data_namespace, "test", %{"foo" => "fooval"})
    :ok
  end
end
