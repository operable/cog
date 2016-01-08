defmodule Cog.Command.ForeignCommand.HelperTest do
  use ExUnit.Case, async: true

  alias Cog.Command.ForeignCommand.Helper
  alias Spanner.Command.Request

  test "reconstructing an invocation with just args" do
    req = %Request{args: ["this", "is", "a", "test"], options: %{}}

    invocation = Helper.reconstruct_invocation(req)

    assert ["this", "is", "a", "test"] = invocation
  end

  test "reconstructing an invocation with args and options" do
    req = %Request{args: ["this", "is", "a", "test"], options: %{prefix: "test", suffix: "ing"}}

    invocation = Helper.reconstruct_invocation(req)

    assert ["--prefix=test", "--suffix=ing", "this", "is", "a", "test"] = invocation
  end

  test "create environment variables from arguments" do
    req = %Request{args: ["foo", "bar", "baz"]}

    env = Helper.args_env(req)

    assert [{"COG_ARGC", "3"},
            {"COG_ARGV_0", "foo"},
            {"COG_ARGV_1", "bar"},
            {"COG_ARGV_2", "baz"}] = env
  end

  test "create environment variables from options" do
    req = %Request{options: %{force: true, id: 123, verbose: true}}

    env = Helper.options_env(req)

    assert [{"COG_OPTS", "force,id,verbose"},
            {"COG_OPT_FORCE", "true"},
            {"COG_OPT_ID", "123"},
            {"COG_OPT_VERBOSE", "true"}] = env
  end
end
