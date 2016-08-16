defmodule Cog.Command.Pipeline.Planner do
  alias Cog.Command.OptionInterpreter
  alias Cog.Command.PermissionInterpreter
  alias Cog.Command.Pipeline.Binder
  alias Cog.Command.Pipeline.Plan
  alias Piper.Command.Ast.Invocation
  alias Piper.Command.Ast.BadValueError

  @spec plan(%Invocation{}, [Map.t], [String.t]) :: {:ok, [%Plan{}]} | {:error, term}
  def plan(invocation, context, perms) when is_list(context),
    do: create_plans(invocation, perms, context, [])

  defp create_plans(_invocation, _perms, [], acc),
    do: {:ok, Enum.reverse(acc)}
  defp create_plans(invocation, perms, [context|t], acc) do
    step = case {t, acc} do
      {[], []} ->
        "last"
      {_, []} ->
        "first"
      {[], _} ->
        "last"
      _ ->
        nil
    end

    case create_plan(invocation, context, context, perms, step) do
      %Plan{}=plan ->
        create_plans(invocation, perms, t, [plan|acc])
      error ->
        error
    end
  end

  defp create_plan(invocation, binding_map, cog_env, permissions, step) do
    try do
      with {:ok, bound} <- Binder.bind(invocation, binding_map),
           {:ok, options, args} <- OptionInterpreter.initialize(bound),
             :allowed <- PermissionInterpreter.check(invocation.meta, options, args, permissions),
        do: %Plan{parser_meta: invocation.meta,
                  options: options,
                  args: args,
                  cog_env: cog_env,
                  invocation_id: invocation.id,
                  invocation_text: to_string(bound),
                  invocation_step: step}
    rescue
      e in BadValueError ->
        {:error, BadValueError.message(e)}
    end
  end

end
