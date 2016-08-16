defmodule Cog.Permissions.EvalTest do

  use ExUnit.Case
  alias Cog.Eval
  alias Cog.Permissions

  defp make_context(command, perms, options \\ %{}, args \\ []) when is_list(perms) do
    Permissions.Context.new(permissions: perms, command: command, options: options,
                            args: args)
  end

  # Force Erlang modules to be reloaded in case tests are being
  # run via mix test.watch
  setup_all do
    for m <- [:piper_rule_lexer, :piper_rule_parser] do
      :code.purge(m)
      :code.delete(m)
      {:module, _} = Code.ensure_compiled(m)
    end
    :ok
  end

  test "simple rule evaluation" do
    {:ok, ast} = :piper_rule_parser.parse_rule("when command is foo:bar must have foo:read")
    context = make_context("foo:bar", ["foo:read"])
    assert Eval.value_of(ast, context) == {true, 0}
  end

  test "match on indexed command args" do
    {:ok, ast} = :piper_rule_parser.parse_rule("when command is foo:bar with arg[1] == 'wubba' must have foo:read")
    context = make_context("foo:bar", ["foo:read"], %{}, ["wubba"])
    assert Eval.value_of(ast, context) == :nomatch
    context = %{context | args: ["foo", "wubba"]}
    assert Eval.value_of(ast, context) == {true, 1}
  end

  test "match on any command arg" do
    {:ok, ast} = :piper_rule_parser.parse_rule("when command is foo:bar with any args in ['wubba'] must have foo:read")
    context = make_context("foo:bar", ["foo:read"], %{}, ["echo", "zulu", "bravo", "wubba"])
    assert Eval.value_of(ast, context) == {true, 1}
    context = %{context | args: ["echo", "zulu"]}
    assert Eval.value_of(ast, context) == :nomatch
  end

  test "match on any command arg with mixed values" do
    {:ok, ast} = :piper_rule_parser.parse_rule("when command is foo:bar with any args in ['wubba', /^f.*/, 10] must have foo:read")
    context = make_context("foo:bar", ["foo:read"], %{}, ["a"])
    assert Eval.value_of(ast, context) == :nomatch
    context = %{context | args: [10]}
    assert Eval.value_of(ast, context) == {true, 1}
    context = %{context | args: [100, "bar", "foo"]}
    assert Eval.value_of(ast, context) == {true, 1}
    context = %{context | args: []}
    assert Eval.value_of(ast, context) == :nomatch
  end

  test "match on all command args" do
    {:ok, ast} = :piper_rule_parser.parse_rule("when command is foo:bar with all arg in [10, 'baz', 'wubba'] must have foo:read")
    context = make_context("foo:bar", ["foo:read"], %{}, [10, "wubba"])
    assert Eval.value_of(ast, context) == {true, 2}
    context = %{context | args: []}
    assert Eval.value_of(ast, context) == :nomatch
  end

  test "match indexed arg using 'in'" do
    {:ok, ast} = :piper_rule_parser.parse_rule("when command is foo:bar with arg[0] in ['baz', false, 100] must have foo:read")
    context = make_context("foo:bar", ["foo:read"], %{}, [true])
    assert Eval.value_of(ast, context) == :nomatch
    context = %{context | args: [100]}
    assert Eval.value_of(ast, context) == {true, 1}
  end

  test "use 'and' to match command args" do
    {:ok, ast} = :piper_rule_parser.parse_rule("when command is foo:bar with arg[0] == \"this is a test\" and arg[1] > 3 must have foo:read")
    context = make_context("foo:bar", ["foo:read"], %{}, ["this is a test", 2])
    assert Eval.value_of(ast, context) == :nomatch
    context = %{context | args: ["this is a test", 4]}
    assert Eval.value_of(ast, context) == {true, 2}
    context = %{context | args: []}
    assert Eval.value_of(ast, context) == :nomatch
  end

  test "use 'or' to match command args" do
    {:ok, ast} = :piper_rule_parser.parse_rule("when command is foo:bar with arg[0] == \"this is a test\" or arg[1] == false must have foo:read")
    context = make_context("foo:bar", ["foo:read"], %{}, ["this is not a test", true])
    assert Eval.value_of(ast, context) == :nomatch
    context = %{context | args: ["this is a test", 100]}
    assert Eval.value_of(ast, context) == {true, 1}
  end

  test "match on named command option" do
    {:ok, ast} = :piper_rule_parser.parse_rule("when command is foo:bar with option[baz] == true must have foo:read")
    context = make_context("foo:bar", ["foo:read"], %{"baz" => "testing"})
    assert Eval.value_of(ast, context) == :nomatch
    context = %{context | options: %{"baz" => true}}
    assert Eval.value_of(ast, context) == {true, 1}
  end

  test "match on any command option" do
    {:ok, ast} = :piper_rule_parser.parse_rule("when command is foo:bar with any option == /^prod.*/ must have foo:read")
    context = make_context("foo:bar", ["foo:read"], %{"bucket" => "prod-assets"})
    assert Eval.value_of(ast, context) == {true, 1}
    context = %{context | options: %{"bucket" => "staging-assets"}}
    assert Eval.value_of(ast, context) == :nomatch
  end

  test "match on all command option" do
    {:ok, ast} = :piper_rule_parser.parse_rule("when command is foo:bar with all option < 10 must have foo:read")
    context = make_context("foo:bar", ["foo:read"], %{"bucket" => "prod-assets"})
    assert Eval.value_of(ast, context) == :nomatch
    context = %{context | options: %{"first" => 3, "second" => "7", "third" => "testing"}}
    assert Eval.value_of(ast, context) == :nomatch
    context = %{context | options: %{"first" => 3, "third" => 8.3}}
    assert Eval.value_of(ast, context) == {true, 2}
  end

  test "option values contained within set of values" do
    {:ok, ast} = :piper_rule_parser.parse_rule("when command is foo:bar with all options in ['staging', 'list'] must have foo:read")
    context = make_context("foo:bar", ["foo:read"], %{"action" => "list", "env" => "prod"})
    assert Eval.value_of(ast, context) == :nomatch
  end

  test "use 'and' to match command options" do
    {:ok, ast} = :piper_rule_parser.parse_rule("""
when command is foo:bar with option[action] == \"list\" and option[target] == \"prod\" must have foo:write
""")
    context = make_context("foo:bar", ["foo:write"], %{"action" => "list", "target" => "prod"})
    assert Eval.value_of(ast, context) == {true, 2}
    context = %{context | options: %{}}
    assert Eval.value_of(ast, context) == :nomatch
  end

  test "use 'or' to match command options" do
    {:ok, ast} = :piper_rule_parser.parse_rule("""
when command is foo:bar with option[action] == \"list\" or option[action] == \"describe" must have foo:read
""")
    context = make_context("foo:bar", ["foo:read"], %{"action" => "list", "target" => "prod"})
    assert Eval.value_of(ast, context) == {true, 1}
    context = %{context | options: %{"action" => "delete"}}
    assert Eval.value_of(ast, context) == :nomatch
  end

  test "use 'and' permissions check" do
    {:ok, ast} = :piper_rule_parser.parse_rule("when command is foo:bar must have foo:read and site:ops")
    context = make_context("foo:bar", ["foo:read"])
    assert Eval.value_of(ast, context) == {false, 0}
    context = %{context | permissions: ["foo:read", "site:ops"]}
    assert Eval.value_of(ast, context) == {true, 0}
  end

  test "use 'or' permissions check" do
    {:ok, ast} = :piper_rule_parser.parse_rule("when command is foo:bar must have foo:read or site:ops")
    context = make_context("foo:bar", ["foo:write"])
    assert Eval.value_of(ast, context) == {false, 0}
    context = %{context | permissions: ["foo:write", "site:ops"]}
    assert Eval.value_of(ast, context) == {true, 0}
  end

  test "use 'any' permissions check" do
    {:ok, ast} = :piper_rule_parser.parse_rule("when command is foo:bar must have any in [foo:read, site:ops, site:mgmt]")
    context = make_context("foo:bar", ["foo:write"])
    assert Eval.value_of(ast, context) == {false, 0}
    context = %{context | permissions: ["aws:read", "site:support", "site:mgmt"]}
    assert Eval.value_of(ast, context) == {true, 0}
  end

  test "use 'all' permissions check" do
    {:ok, ast} = :piper_rule_parser.parse_rule("when command is foo:bar must have all in [foo:write, site:ops, site:mgmt]")
    context = make_context("foo:bar", ["foo:read", "site:ops", "site:mgmt"])
    assert Eval.value_of(ast, context) == {false, 0}
    context = %{context | permissions: ["site:ops", "site:mgmt", "foo:write"]}
    assert Eval.value_of(ast, context) == {true, 0}
  end

  test "complex rule" do
    {:ok, ast} = :piper_rule_parser.parse_rule("""
when command is foo:bar with (option[action] == \"delete\" and arg[0] == /^prod-db/) or (option[action] == \"restart\" and arg[0] == /^prod-lb/)
must have foo:write
""")
    context = make_context("foo:bar", ["foo:write"], %{"action" => "delete"}, ["staging-db-001"])
    assert Eval.value_of(ast, context) == :nomatch
    context = %{context | args: ["prod-db-002"]}
    assert Eval.value_of(ast, context) == {true, 2}
  end

  test "in expr referencing an option" do
    {:ok, ast} = :piper_rule_parser.parse_rule("""
when command is debug:opts with option[list] in ["foo", "bar"] allow
    """)
    context = make_context("debug:opts", [], %{"list" => "foo"})
    assert Eval.value_of(ast, context) == {true, 1}
    context = make_context("debug:opts", [], %{"list" => "baz"})
    assert Eval.value_of(ast, context) == :nomatch
  end

  test "in expr referencing an arg" do
    {:ok, ast} = :piper_rule_parser.parse_rule("""
when command is debug:opts with arg[0] in ["foo", "bar"] allow
    """)
    context = make_context("debug:opts", [], %{}, ["foo", "wubba"])
    assert Eval.value_of(ast, context) == {true, 1}
    context = make_context("debug:opts", ["baz", "quux"])
    assert Eval.value_of(ast, context) == :nomatch
  end

end
