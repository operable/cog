defmodule Cog.Command.Pipeline.Binder do
  alias Piper.Common.Scope
  alias Piper.Common.Bindable

  def bind(unbound_invocation, context) when is_map(context) do
    scope = Scope.from_map(context)
    try do
      with({:ok, resolved_scope} <- Bindable.resolve(unbound_invocation, scope),
           {:ok, bound_invocation, ^resolved_scope} <- Bindable.bind(unbound_invocation, resolved_scope)) do
        {:ok, bound_invocation}
      end
    catch
      %Piper.Common.BindError{meta: meta, reason: reason} ->
        {:error, {reason, meta}}
    end
  end

end
