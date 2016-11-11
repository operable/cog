defmodule Cog.Test.Commands.TeeTest do
  use Cog.CommandCase, command_module: Cog.Commands.Tee

  alias Cog.Command.Service.DataStore

  @data_namespace [ "commands", "tee" ]

  test "tee passes pipeline output through" do
    response = new_req(args: ["myfoo"], cog_env: %{"foo" => "fooval"})
               |> send_req()
               |> unwrap()

    assert(%{foo: "fooval"} = response)
  end

  test "tee overwrites content for existing keys" do
    key = "test"

    # First request
    new_req(args: [key], cog_env: %{"foo" => "fooval2"})
    |> send_req()

    data = DataStore.fetch(@data_namespace, key)
           |> unwrap()

    assert(%{"foo" => "fooval2"} = data)

    # Second request
    new_req(args: [key], cog_env: %{"foo" => "fooval3"})
    |> send_req()

    data2 = DataStore.fetch(@data_namespace, key)
            |> unwrap()

    assert(%{"foo" => "fooval3"} = data2)
  end

end
