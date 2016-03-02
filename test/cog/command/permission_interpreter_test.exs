defmodule Cog.Command.PermissionInterpreter.Test do
  use ExUnit.Case

  @empty_context %{}
  @no_options []

  import Cog.ExecutorHelpers, only: [bound_invocation: 3]
  alias Cog.Command.OptionInterpreter
  alias Cog.Command.PermissionInterpreter

  test "passes when user has permission" do
    {:ok, command, options, args} = prepare("test:test",
                                         @empty_context,
                                         rules: ["when command is test:test must have test:admin"])
    result = PermissionInterpreter.check(command, options, args, ["test:admin"])
    assert :allowed = result
  end

  test "fails when no rule matches the invocation" do
    {:ok, command, options, args} = prepare("test:test --really=yes",
                                         @empty_context,
                                         options: [[name: "really", type: "bool"],
                                                   [name: "fuzz-factor", type: "int"]],
                                         rules: ["when command is test:test with option[really] == false must have test:admin"])
    result = PermissionInterpreter.check(command, options, args, ["test:other"])
    assert {:error, :no_rule} = result
  end

  test "fails when user doesn't have permission" do
    {:ok, command, options, args} = prepare("test:test --really=yes",
                                         @empty_context,
                                         options: [[name: "really", type: "bool"],
                                                   [name: "fuzz-factor", type: "int"]],
                                         rules: ["when command is test:test with option[really] == true must have test:admin",
                                                 "when command is test:test with option[really] == false must have test:admin",
                                                 "when command is test:test with option[fuzz-factor] == 5 must have test:admin"])
    result = PermissionInterpreter.check(command, options, args, ["test:other"])
    assert {:error, {:denied, _rule}} = result
  end

  ########################################################################

  defp prepare(invocation_text, context, command_spec) do
    bound_invocation = bound_invocation(invocation_text, context, command_spec)
    case OptionInterpreter.initialize(bound_invocation) do
      {:ok, options, args} ->
        {:ok, bound_invocation.meta, options, args}
      {:error, _}=error ->
        error
    end
  end

end
