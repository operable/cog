defmodule Cog.Test.Commands.FilterTest do
  use Cog.CommandCase, command_module: Cog.Commands.Filter

  test "returns an item that matches at a specific key" do
    data = %{"foo" => %{"bar" => "stuff", "baz" => "other stuff"}}

    {:ok, match} = new_req(cog_env: data,
                           options: %{"path" => "foo.bar",
                                      "matches" => "stuff"})
    |> send_req()

    assert(%{foo: %{bar: "stuff",
                    baz: "other stuff"}} = match)
  end

  test "returns nothing when an item does not match at a specific key " do
    data = %{"foo" => %{"bar" => "stuff", "baz" => "other stuff"}}

    {:ok, no_match} = new_req(cog_env: data,
                           options: %{"path" => "foo.bar",
                                      "matches" => "no match here"})
    |> send_req()

    assert(nil == no_match)
  end

  test "returns an item based on the presence of a key" do
    data = %{"foo" => %{"bar" => "stuff"}}

    {:ok, match} = new_req(cog_env: data,
                           options: %{"path" => "foo.bar"})
    |> send_req()

    assert(%{foo: %{bar: "stuff"}} = match)
  end

  test "returns nothing when the requested key is not present" do
    data = %{"foo" => %{"bar" => "stuff"}}

    {:ok, no_match} = new_req(cog_env: data,
                           options: %{"path" => "foo.baz"})
    |> send_req()

    assert(nil == no_match)
  end
end


