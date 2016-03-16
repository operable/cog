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
    with %Plan{}=plan <- _plan(invocation, %{}, context, perms),
      do: {:ok, [plan]}
  end
  def plan(%Invocation{meta: %Command{execution: "multiple"}}=invocation, context, perms) when is_list(context) do
    result = Enum.reduce_while(context, [], fn(ctx, acc) ->
      case _plan(invocation, ctx, ctx, perms) do
        %Plan{}=plan ->
          {:cont, [plan|acc]}
        {:error, _}=error ->
          {:halt, error}
      end
    end)

    case result do
      plans when is_list(plans) ->
        {:ok, Enum.reverse(plans)}
      {:error, _}=error ->
        error
    end
  end

  defp _plan(invocation, binding_map, cog_env, permissions) do
    with {:ok, bound} <- Binder.bind(invocation, binding_map),
         {:ok, options, args} <- OptionInterpreter.initialize(bound),
         :allowed <- PermissionInterpreter.check(invocation.meta, options, args, permissions),
      do: %Plan{command: invocation.meta,
                options: options,
                args: args,
                cog_env: cog_env,
                invocation_text: to_string(bound)}
  end

end
