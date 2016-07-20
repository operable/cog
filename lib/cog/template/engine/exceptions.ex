defmodule Cog.Template.Engine.ForbiddenElixirError do
  defexception [:aliases, :fun, :arg_exprs, :line]
  def message(error) do
    bad_fun = "#{inspect(Module.concat(error.aliases))}.#{error.fun}/#{length(error.arg_exprs)}"
    "Can't call Elixir function #{bad_fun} on line #{error.line}"
  end
end

defmodule Cog.Template.Engine.ForbiddenErlangError do
  defexception [:mod, :fun, :arg_exprs, :line]
  def message(error),
    do: "Can't call Erlang function #{error.mod}:#{error.fun}/#{length(error.arg_exprs)} on line #{error.line}"
end
