defmodule Cog.Command.Pipeline.Planner.Test do
  use ExUnit.Case

  alias Cog.Command.Pipeline.Planner
  alias Cog.Command.Pipeline.Plan
  alias Piper.Permissions.Ast.Rule
  import Cog.ExecutorHelpers, only: [unbound_invocation: 2]

  ########################################################################
  # cog_env handling

  test "plan a multiple invocation with 1-item context" do
    invocation = unbound_invocation("test:test --foo=$var",
                                    options: [[name: "foo"]],
                                    rules: ["when command is test:test must have test:admin"],
                                    execution: "multiple")
    plans = Planner.plan(invocation, [%{"var" => "stuff"}], ["test:admin"])

    command = invocation.meta
    assert {:ok, [%Plan{command: ^command,
                        options: %{"foo" => "stuff"},
                        args: [],
                        cog_env: %{"var" => "stuff"}}]} = plans

  end

  test "plan a multiple invocation with multi-item context" do
    invocation = unbound_invocation("test:test --foo=$var",
                                    options: [[name: "foo"]],
                                    rules: ["when command is test:test must have test:admin"],
                                    execution: "multiple")
    plans = Planner.plan(invocation, [%{"var" => "stuff"},
                                      %{"var" => "other"},
                                      %{"var" => "thingies"}],
                         ["test:admin"])

    command = invocation.meta
    assert {:ok, [%Plan{command: ^command,
                        options: %{"foo" => "stuff"},
                        args: [],
                        cog_env: %{"var" => "stuff"}},
                  %Plan{command: ^command,
                        options: %{"foo" => "other"},
                        args: [],
                        cog_env: %{"var" => "other"}},
                  %Plan{command: ^command,
                        options: %{"foo" => "thingies"},
                        args: [],
                        cog_env: %{"var" => "thingies"}}
                 ]} = plans
  end

  test "plan a once invocation with a 1-item context" do
    invocation = unbound_invocation("test:test --foo=bar",
                                    options: [[name: "foo"]],
                                    rules: ["when command is test:test must have test:admin"],
                                    execution: "once")
    plans = Planner.plan(invocation,
                         [%{"var" => "stuff"}],
                         ["test:admin"])

    command = invocation.meta
    assert {:ok, [%Plan{command: ^command,
                        options: %{"foo" => "bar"},
                        args: [],
                        cog_env: [%{"var" => "stuff"}]}]} = plans
  end

  test "plan a once invocation with a multi-item context" do
    invocation = unbound_invocation("test:test --foo=bar",
                                    options: [[name: "foo"]],
                                    rules: ["when command is test:test must have test:admin"],
                                    execution: "once")
    plans = Planner.plan(invocation,
                         [%{"var" => "stuff"},
                          %{"var" => "more_stuff"},
                          %{"var" => "even_more_stuff"}],
                         ["test:admin"])

    command = invocation.meta
    assert {:ok, [%Plan{command: ^command,
                        options: %{"foo" => "bar"},
                        args: [],
                        cog_env: [%{"var" => "stuff"},
                                  %{"var" => "more_stuff"},
                                  %{"var" => "even_more_stuff"}]}]} = plans
  end

  ########################################################################
  # error handling

  # binding errors
  test "missing variable" do
    invocation = unbound_invocation("test:test --foo=$var",
                                    options: [[name: "foo"]],
                                    rules: ["when command is test:test must have test:admin"])
    plans = Planner.plan(invocation, [%{}], ["test:admin"])

    assert plans == {:error, {:missing_key, "var"}}
  end

  # option processing errors
  test "bad type variable" do
    invocation = unbound_invocation("test:test --foo=123",
                                    options: [[name: "foo"]],
                                    rules: ["when command is test:test must have test:admin"])
    plans = Planner.plan(invocation, [%{}], ["test:admin"])

    assert {:error, "Type Error: `123` is not of type `string`"} = plans
  end

  test "end of input" do
    invocation = unbound_invocation("test:test --foo",
                                    options: [[name: "foo"]],
                                    rules: ["when command is test:test must have test:admin"])
    plans = Planner.plan(invocation, [%{}], ["test:admin"])

    assert {:error, "Unexpected end of input."} == plans
  end

  test "no value" do
    invocation = unbound_invocation("test:test --foo --bar=baz",
                                    options: [[name: "foo"],
                                              [name: "bar"]],
                                    rules: ["when command is test:test must have test:admin"])
    plans = Planner.plan(invocation, [%{}], ["test:admin"])

    assert {:error, "No value supplied!"} == plans # TODO: need to know what option the value is missing for
  end

  test "missing required option" do
    invocation = unbound_invocation("test:test --bar=baz",
                                    options: [[name: "foo", required: true],
                                              [name: "bar"]],
                                    rules: ["when command is test:test must have test:admin"])
    plans = Planner.plan(invocation, [%{}], ["test:admin"])

    assert {:error, "Looks like you forgot to include some required options: 'foo'"} == plans
  end





  # permission errors
  test "denied by rule" do
    invocation = unbound_invocation("test:test --foo=$var",
                                    options: [[name: "foo"]],
                                    rules: ["when command is test:test must have test:admin"])
    plans = Planner.plan(invocation, [%{"var" => "stuff"}], ["test:test"])

    assert {:error, {:denied, %Rule{}}} = plans
  end

  test "no matching rule" do
    invocation = unbound_invocation("test:test --foo=$var",
                                    options: [[name: "foo"]],
                                    rules: ["when command is test:test with option[foo] == \"blah\" must have test:admin"])
    plans = Planner.plan(invocation, [%{"var" => "stuff"}], ["test:test"])

    assert {:error, :no_rule} = plans
  end



end
