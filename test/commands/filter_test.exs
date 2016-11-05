defmodule Cog.Test.Commands.FilterTest do
  use Cog.CommandCase, command_module: Cog.Commands.Filter

  test "can match on objects on a specific path" do
    data = %{"foo" => %{"bar" => "stuff", "baz" => "other stuff"}}

    {:ok, match} = new_req(cog_env: data,
                           options: %{"path" => "foo.bar",
                                      "matches" => "stuff"})
    |> send_req()

    {:ok, no_match} = new_req(cog_env: data,
                           options: %{"path" => "foo.bar",
                                      "matches" => "other stuff"})
    |> send_req()

    assert(%{foo: %{bar: "stuff",
                    baz: "other stuff"}} = match)

    assert(nil == no_match)
  end

  test "filters a list of things based on a key" do
    data = %{"foo" => %{"bar" => "stuff"}}

    {:ok, match} = new_req(cog_env: data,
                           options: %{"path" => "foo.bar"})
    |> send_req()

    {:ok, no_match} = new_req(cog_env: data,
                           options: %{"path" => "foo.baz"})
    |> send_req()

    assert(%{foo: %{bar: "stuff"}} = match)

    assert(nil == no_match)
  end
end


