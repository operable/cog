defmodule Cog.Command.Pipeline.Planner do
  alias Cog.Command.OptionInterpreter
  alias Cog.Command.PermissionInterpreter
  alias Cog.Command.Pipeline.Binder
  alias Cog.Command.Pipeline.Plan
  alias Piper.Command.Ast.Invocation

  @spec plan(%Invocation{}, [Map.t], [String.t]) :: {:ok, [%Plan{}]} | {:error, term}
  def plan(invocation, context, perms) when is_list(context) do
    bundle_name = invocation.meta.bundle_name
    version = invocation.meta.version
    relay = Cog.Relay.Relays.pick_one(bundle_name, version)
    create_plans(invocation, relay, perms, context, [])
  end

  defp create_plans(_invocation, _relay, _perms, [], acc),
    do: {:ok, Enum.reverse(acc)}
  defp create_plans(invocation, relay, perms, [context|t], acc) do
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

    case create_plan(invocation, relay, context, context, perms, step) do
      %Plan{}=plan ->
        create_plans(invocation, relay, perms, t, [plan|acc])
      error ->
        error
    end
  end

  defp create_plan(invocation, relay, binding_map, cog_env, permissions, step) do
    with {:ok, bound} <- Binder.bind(invocation, binding_map),
         {:ok, options, args} <- OptionInterpreter.initialize(bound),
         :allowed <- PermissionInterpreter.check(invocation.meta, options, args, permissions),
    do: %Plan{parser_meta: invocation.meta,
              relay_id: relay,
              options: options,
              args: args,
              cog_env: cog_env,
              invocation_id: invocation.id,
              invocation_text: to_string(bound),
              invocation_step: step}
  end

end
