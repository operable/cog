defmodule Cog.Command.PermissionInterpreter do

  alias Piper.Permissions.Parser
  alias Cog.Permissions
  alias Cog.Models.Command

  def check(%Command{enforcing: false}, _options, _args, _perms),
    do: :allowed
  def check(command, options, args, perms) do
    context = Permissions.Context.new(permissions: perms,
                                      command: Cog.Models.Command.full_name(command),
                                      options: options,
                                      args: args)
    results = command.rules
    |> Enum.map(&(evaluate(&1, context)))
    |> Enum.reject(&(&1 == :nomatch))
    |> Enum.sort(&by_score/2)
    case results do
      [] ->
        {:error, :no_rule}
      [{true, _, _}|_] ->
        :allowed
      [{false, _, rule}|_] ->
        {:error, {:denied, rule}}
    end
  end

  defp by_score({true, n, _}, {false, n, _}),
    do: true
  defp by_score({_, n1, _}, {_, n2, _}),
    do: n1 > n2

  defp evaluate(rule, context) do
    rule = Parser.json_to_rule!(rule.parse_tree)
    case Cog.Eval.value_of(rule, context) do
      {{:error, :bad_reference}, _} ->
        :nomatch
      :nomatch ->
        :nomatch
      {result, count} ->
        {result, count, rule}
    end
  end

end
