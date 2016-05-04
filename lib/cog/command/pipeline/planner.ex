defmodule Cog.Command.Pipeline.Planner do

  alias Cog.Command.OptionInterpreter
  alias Cog.Command.PermissionInterpreter
  alias Cog.Command.Pipeline.Binder
  alias Cog.Command.Pipeline.Plan
  alias Cog.Models.Command
  alias Piper.Command.Ast.Invocation

  # TODO: need to indicate special status of once w/r/t binding
  @spec plan(%Invocation{}, [Map.t], [String.t]) :: {:ok, [%Plan{}]} | {:error, term}
  def plan(%Invocation{meta: %Command{execution: "once"}}=invocation, context, perms) when is_list(context) do
    with %Plan{}=plan <- create_plan(invocation, %{}, context, perms),
      do: {:ok, [plan]}
  end
  def plan(%Invocation{meta: %Command{execution: "multiple"}}=invocation, context, perms) when is_list(context),
    do: create_plans(invocation, perms, context, [])

  defp create_plans(_invocation, _perms, [], acc),
    do: {:ok, Enum.reverse(acc)}
  defp create_plans(invocation, perms, [context|t], acc) do
    stage_pos = case {t, acc} do
      {_, []} ->
        :first
      {[], _} ->
        :last
      _ ->
        nil
    end

    case create_plan(invocation, context, context, perms, stage_pos) do
      %Plan{}=plan ->
        create_plans(invocation, perms, t, [plan|acc])
      error ->
        error
    end
  end

  defp create_plan(invocation, binding_map, cog_env, permissions, stage_pos \\ nil) do
    with {:ok, bound} <- Binder.bind(invocation, binding_map),
         {:ok, options, args} <- OptionInterpreter.initialize(bound),
         :allowed <- PermissionInterpreter.check(invocation.meta, options, args, permissions),
      do: %Plan{command: invocation.meta,
                options: options,
                args: args,
                cog_env: cog_env,
                invocation_text: to_string(bound),
                stage_pos: stage_pos}
  end

end
