defmodule Cog.Command.Pipeline.Binder do
  alias Piper.Command.Bind.Scope
  alias Piper.Command.Bindable

  def bind(unbound_invocation, context) when is_map(context) do
    scope = Scope.from_map(context)
    try do
      case Bindable.resolve(unbound_invocation, scope) do
        {:ok, resolved_scope} ->
          case Bindable.bind(unbound_invocation, resolved_scope) do
            {:ok, bound_invocation, ^resolved_scope} ->
              {:ok, bound_invocation}
            error ->
              error
          end
        {:error, _}=error ->
          error
      end
    catch
      %Piper.Command.BindError{meta: meta, reason: reason} ->
        {:error, {reason, meta}}
    end
  end

end
