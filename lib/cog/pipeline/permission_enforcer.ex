defmodule Cog.Pipeline.PermissionEnforcer do

  alias Piper.Permissions.Parser
  alias Cog.Pipeline.ParserMeta
  alias Cog.Permissions

  def check(%ParserMeta{}=meta, options, args, perms) do
    do_check(Application.get_env(:cog, :access_rules, :enforcing), meta, options, args, perms)
  end

  defp do_check(:unenforcing, _, _, _, _), do: :allowed
  defp do_check(:enforcing, %ParserMeta{}=meta, options, args, perms) do
    context = Permissions.Context.new(permissions: perms,
                                      command: meta.full_command_name,
                                      options: options,
                                      args: args)
    results = meta.rules
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
