defmodule Cog.Template.Engine.ForbiddenCallError do
  defexception [:target, :fun, :arg_exprs, :line]
  def message(error) do
    function = cond do
      is_list(error.target) ->
        "Elixir function `#{inspect(Module.concat(error.target))}.#{error.fun}/#{length(error.arg_exprs)}`"
      is_atom(error.target) ->
        "Erlang function `#{error.target}:#{error.fun}/#{length(error.arg_exprs)}`"
      match?({var, _, ctx} when is_atom(var) and is_atom(ctx), error.target) ->
        "function `#{error.fun}/#{length(error.arg_exprs)}` on variable `#{Tuple.to_list(error.target) |> hd}`"
    end
    "Disallowed call to #{function} on line #{error.line}"
  end
end
