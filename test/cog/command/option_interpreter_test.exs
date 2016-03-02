defmodule Cog.Command.OptionInterpreter.Test do
  use ExUnit.Case

  import Cog.ExecutorHelpers, only: [bound_invocation: 3]
  alias Cog.Command.OptionInterpreter

  # TODO: failure cases
  # TODO: missing bindings
  # TODO: options specified as variables, e.g. "foo --$opt=$var", "foo --$opt='value'"

  bad_values = [
    ["string", "int", 123],
    ["string", "float", 123.45],
    ["string", "bool", true],
    ["float", "string", "foo"],
    ["float", "bool", true],
    ["float", "list", "foo,bar,baz"],
    ["int", "string", "foo"],
    ["int", "float", 123.45],
    ["int", "bool", true],
    ["bool", "float", 123.45],
    ["list", "int", 123],
    ["list", "float", 123.45],
    ["list", "bool", true],
    ["incr", "string", "foo"],
    ["incr", "bool", true],
    ["incr", "float", 123.45],
    ["incr", "list", "foo,bar,baz"]
  ]

  bad_values |> Enum.each(fn([type, given_type, value]) ->
    test "an option of type `#{type}` with a value of type `#{given_type}` raises an error" do
      opt_args = options_and_args("test-command --stuff=#{inspect unquote(value)}",
                                  %{},
                                  options: [[name: "stuff", type: unquote(type)]])
      assert {:error, "Type Error: `#{inspect unquote(value)}` is not of type `#{unquote(type)}`"} == opt_args
    end
  end)

  # option type, input value, output value
  kv_options = [
    ["string", "value", "value"],
    ["int", 123, 123],
    ["int", -123, -123],
    ["int", "123", 123],
    ["int", "-123", -123],
    ["float", 123.45, 123.45],
    ["float", 123, 123.0],
    ["float", "123.45", 123.45],
    ["float", -123.45, -123.45],
    ["float", -123, -123.0],
    ["float", "-123.45", -123.45],
    ["list", "foo,bar,baz", ["foo","bar","baz"]]
  ]

  optionally_kv_options = [
    ["bool", true, true],
    ["bool", false, false],
    ["bool", -1, false],
    ["bool", 0, false],
    ["bool", 1, true],
    ["bool", 42, true],
    ["bool", "y", true],
    ["bool", "n", false],
    ["bool", "t", true],
    ["bool", "f", false],
    ["bool", "yes", true],
    ["bool", "no", false],
    ["bool", "on", true],
    ["bool", "off", false],
    ["bool", "true", true], # not sure why this works
    ["bool", "false", false],
    ["bool", "blahblahblah", false]
  ]

  kv_options ++ optionally_kv_options |> Enum.each(fn([type, input, output]) ->
    test "`#{inspect input}` is processed as `#{inspect output}` as a #{type} option, when specified as a variable with an equal sign" do
      opt_args = options_and_args("test-command --stuff=$var",
                                  %{"var" => unquote(input)},
                                  options: [[name: "stuff", type: unquote(type)]])
      assert_options_and_args(opt_args, %{"stuff" => unquote(output)}, [])
    end

    test "`#{inspect input}` is processed as `#{inspect output}` as a #{type} option, when specified as a variable with an equal sign with a short flag" do
      opt_args = options_and_args("test-command -s=$var",
                                  %{"var" => unquote(input)},
                                  options: [[name: "stuff", type: unquote(type), short_flag: "s"]])
      assert_options_and_args(opt_args, %{"stuff" => unquote(output)}, [])
    end

    test "`#{inspect input}` is processed as `#{inspect output}` as a #{type} option, when specified directly with an equal sign" do
      opt_args = options_and_args("test-command --stuff=#{inspect unquote(input)}",
                                  %{},
                                  options: [[name: "stuff", type: unquote(type)]])
      assert_options_and_args(opt_args, %{"stuff" => unquote(output)}, [])
    end

    test "`#{inspect input}` is processed as `#{inspect output}` as a #{type} option, when specified directly with an equal sign with a short flag" do
      opt_args = options_and_args("test-command -s=#{inspect unquote(input)}",
                                  %{},
                                  options: [[name: "stuff", type: unquote(type), short_flag: "s"]])
      assert_options_and_args(opt_args, %{"stuff" => unquote(output)}, [])
    end
  end)

  kv_options |> Enum.each(fn([type, input, output]) ->
    test "`#{inspect input}` is processed as `#{inspect output}` as a #{type} option, when specified as a variable without an equal sign" do
      opt_args = options_and_args("test-command --stuff $var",
                                  %{"var" => unquote(input)},
                                  options: [[name: "stuff", type: unquote(type)]])
      assert_options_and_args(opt_args, %{"stuff" => unquote(output)}, [])
    end

    test "`#{inspect input}` is processed as `#{inspect output}` as a #{type} option, when specified as a variable without an equal sign with a short flag" do
      opt_args = options_and_args("test-command -s $var",
                                  %{"var" => unquote(input)},
                                  options: [[name: "stuff", type: unquote(type), short_flag: "s"]])
      assert_options_and_args(opt_args, %{"stuff" => unquote(output)}, [])
    end

    test "`#{inspect input}` is processed as `#{inspect output}` as a #{type} option, when specified directly without an equal sign" do
      opt_args = options_and_args("test-command --stuff #{inspect unquote(input)}",
                                  %{},
                                  options: [[name: "stuff", type: unquote(type)]])
      assert_options_and_args(opt_args, %{"stuff" => unquote(output)}, [])
    end

    test "`#{inspect input}` is processed as `#{inspect output}` as a #{type} option, when specified directly without an equal sign with a short flag" do
      opt_args = options_and_args("test-command -s #{inspect unquote(input)}",
                                  %{},
                                  options: [[name: "stuff", type: unquote(type), short_flag: "s"]])
      assert_options_and_args(opt_args, %{"stuff" => unquote(output)}, [])
    end

  end)

  ["string", "int", "float", "list"] |> Enum.each(fn(type) ->
    test "a #{type} option with no value specified, at the end of the invocation, results in an error" do
      opt_args = options_and_args("test-command --stuff",
                                  %{},
                                  options: [[name: "stuff", type: unquote(type)]])
      assert {:error, "Unexpected end of input."} = opt_args
    end

    test "a #{type} option with no value specified, using a short flag, at the end of the invocation, results in an error" do
      opt_args = options_and_args("test-command -s",
                                  %{},
                                  options: [[name: "stuff", type: unquote(type), short_flag: "s"]])
      assert {:error, "Unexpected end of input."} = opt_args
    end

    test "a #{type} option with no value specified, with subsequent options, results in an error" do
      opt_args = options_and_args("test-command --stuff --other=foo",
                                  %{},
                                  options: [[name: "stuff", type: unquote(type)],
                                            [name: "other", type: "string"]])
      assert {:error, "No value supplied!"} = opt_args
    end

    test "a #{type} option with no value specified, using a short flag, with subsequent options, results in an error" do
      opt_args = options_and_args("test-command -s --other=foo",
                                  %{},
                                  options: [[name: "stuff", type: unquote(type), short_flag: "s"],
                                            [name: "other", type: "string"]])
      assert {:error, "No value supplied!"} = opt_args
    end
  end)

  test "boolean option without a value is interpreted as true" do
    opt_args = options_and_args("test-command --stuff",
                                %{},
                                options: [[name: "stuff", type: "bool"]])
    assert_options_and_args(opt_args, %{"stuff" => true}, [])
  end

  test "boolean option specified with a short flag without a value is interpreted as true" do
    opt_args = options_and_args("test-command -s",
                                %{},
                                options: [[name: "stuff", type: "bool", short_flag: "s"]])
    assert_options_and_args(opt_args, %{"stuff" => true}, [])
  end

  test "boolean option without a value given *without* an equal sign is true, and the value is interpreted as an argument" do
    opt_args = options_and_args("test-command --stuff false",
                                %{},
                                options: [[name: "stuff", type: "bool"]])
    assert_options_and_args(opt_args, %{"stuff" => true}, [false])
  end

  test "incr option by itself" do
    opt_args = options_and_args("test-command -v",
                                %{},
                                options: [[name: "verbose", type: "incr", short_flag: "v"]])
    assert_options_and_args(opt_args, %{"verbose" => 1}, [])
  end

  test "incr option given with a parameter" do
    opt_args = options_and_args("test-command -v=3",
                                %{},
                                options: [[name: "verbose", type: "incr", short_flag: "v"]])
    assert_options_and_args(opt_args, %{"verbose" => 3}, [])
  end

  test "incr option without actually being specified" do
    opt_args = options_and_args("test-command",
                                %{},
                                options: [[name: "verbose", type: "incr", short_flag: "v"]])
    assert_options_and_args(opt_args, %{"verbose" => 0}, [])
  end

  test "incr option specified multiple times" do
    opt_args = options_and_args("test-command -v -v -v -v",
                                %{},
                                options: [[name: "verbose", type: "incr", short_flag: "v"]])
    assert_options_and_args(opt_args, %{"verbose" => 4}, [])
  end

  test "incr option specified multiple times with values" do
    opt_args = options_and_args("test-command -v -v=2 -v=3 -v=62",
                                %{},
                                options: [[name: "verbose", type: "incr", short_flag: "v"]])
    assert_options_and_args(opt_args, %{"verbose" => 68}, [])
  end

  test "incr option specified with negative values" do
    opt_args = options_and_args("test-command -v=-1",
                                %{},
                                options: [[name: "verbose", type: "incr", short_flag: "v"]])
    assert_options_and_args(opt_args, %{"verbose" => -1}, [])
  end

  args = [["string", "value"],
          ["integer", 123],
          ["float", 123.45],
          ["bool", true]]
  Enum.each(args, fn([type, value]) ->
    test "#{type} argument specified directly is processed in a type-aware way" do
      opt_args = options_and_args("test-command #{inspect unquote(value)}", %{})
      assert_options_and_args(opt_args, %{}, [unquote(value)])
    end

    test "#{type} argument specified as a variable is processed in a type-aware way" do
      opt_args = options_and_args("test-command $var", %{"var" => unquote(value)})
      assert_options_and_args(opt_args, %{}, [unquote(value)])
    end
  end)

  test "unrecognized options are dropped" do
    opt_args = options_and_args("ec2 --tags=$var1 --stuff=$var2",
                                %{"var1" => "monkeys", "var2" => "stuff"},
                                options: [[name: "tags"]])
    assert_options_and_args(opt_args, %{"tags" => "monkeys"}, [])
  end

  test "required options are required" do
    opt_args = options_and_args("test-command --tags=monkeys",
                                %{},
                                options: [[name: "tags", required: false],
                                          [name: "needed", required: true],
                                          [name: "really_needed", required: true]])
    assert {:error, "Looks like you forgot to include some required options: 'needed, really_needed'"} = opt_args
  end


  test "complex example" do
    opt_args = options_and_args("test-command --foo=bar --baz=$var --active -z=123 456 true what",
                                %{"var" => "one,two,three",
                                  "opt_var" => "monkey"},
                                options: [[name: "foo"],
                                          [name: "baz", type: "list"],
                                          [name: "active", type: "bool"],
                                          [name: "layer", type: "int", short_flag: "z"]])
    assert_options_and_args(opt_args,  %{"foo" => "bar",
                                         "baz" => ["one" , "two", "three"],
                                         "active" => true,
                                         "layer" => 123}, [456, true, "what"])
  end

  ########################################################################

  defp options_and_args(invocation_text, context, command_spec \\ []) do
    invocation_text
    |> bound_invocation(context, command_spec)
    |> OptionInterpreter.initialize
  end

  defp assert_options_and_args({:ok, options, args}, expected_options, expected_args) do
    assert options == expected_options
    assert args == expected_args
  end

end
