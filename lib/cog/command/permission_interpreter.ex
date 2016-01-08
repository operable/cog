defmodule Cog.Command.PermissionInterpreter do

  require Logger

  alias Piper.Command.Ast
  alias Piper.Permissions.Parser
  alias Cog.Command
  alias Cog.Permissions

  def check(handle, adapter, %Ast.Invocation{}=invocation) do
    case Command.UserPermissionsCache.fetch(username: handle, adapter: adapter) do
      :not_found ->
        :ignore
      {:ok, {user, perms}} ->
        check_permissions(invocation, user, perms)
    end
  end

  defp check_permissions(invoke, user, perms) do
    context = Permissions.Context.new(user: user, permissions: perms, command: invoke.command,
                                      options: invoke.options, args: invoke.args)
    {:ok, rules} = Command.RuleCache.fetch(invoke.command)
    results = Enum.map(rules, &(evaluate(&1, context)))
    |> Enum.filter(fn({type, _, _}) -> type != :nomatch end)
    |> Enum.sort(&sort_perm_checks/2)
    case results do
      [] ->
        {:no_rule, invoke}
      [{true, _, _}|_] ->
        :allowed
      [{false, _, rule}|_] ->
        {:denied, invoke, rule}
    end
  end

  defp sort_perm_checks({true, n, _}, {false, n, _}),
  do: true
  defp sort_perm_checks({_, n1, _}, {_, n2, _}),
  do: n1 > n2

  defp evaluate(rule, context) do
    rule = Parser.json_to_rule!(rule.parse_tree)
    case Cog.Eval.value_of(rule, context) do
      {{:error, :bad_reference}, _} ->
        {:nomatch, 0, rule}
      :nomatch ->
        {:nomatch, 0, rule}
      {result, count} ->
        {result, count, rule}
    end
  end

end
