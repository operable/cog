defmodule Cog.Command.PermissionInterpreter do

  alias Piper.Permissions.Parser
  alias Cog.Permissions
  alias Cog.Models.CommandVersion

  def check(%CommandVersion{}=command_version, options, args, perms) do
    context = Permissions.Context.new(permissions: perms,
                                      command: CommandVersion.full_name(command_version),
                                      options: options,
                                      args: args)
    results = command_version.command.rules
    |> Enum.filter(&(&1.enabled))
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
