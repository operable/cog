defimpl Cog.Eval, for: Piper.Permissions.Ast.PermissionExpr do

  alias Cog.Eval
  alias Piper.Permissions.Ast

  def value_of(%Ast.PermissionExpr{op: :has, perms: perm}, context) do
    {perm, context} = Eval.value_of(perm, context)
    {Enum.member?(context.permissions, perm), context}
  end
  def value_of(%Ast.PermissionExpr{op: :any, perms: perms}, context) do
    has_any(perms, context.permissions, context)
  end
  def value_of(%Ast.PermissionExpr{op: :all, perms: perms}, context) do
    has_all(perms, context.permissions, context)
  end

  defp has_any(%Ast.List{}=perms, user_perms, context) do
    {perms, context} = Eval.value_of(perms, context)
    has_any(perms, user_perms, context)
  end
  defp has_any([], _user_perms, context) do
    {false, context}
  end
  defp has_any([h|t], user_perms, context) do
    {h, context} = Eval.value_of(h, context)
    case Enum.member?(user_perms, h) do
      true ->
        {true, context}
      false ->
        has_any(t, user_perms, context)
    end
  end

  defp has_all(%Ast.List{}=perms, user_perms, context) do
    {perms, context} = Eval.value_of(perms, context)
    has_all(perms, user_perms, context)
  end
  defp has_all([], _user_perms, context) do
    {true, context}
  end
  defp has_all([h|t], user_perms, context) do
    {h, context} = Eval.value_of(h, context)
    case Enum.member?(user_perms, h) do
      false ->
        {false, context}
      true ->
        has_all(t, user_perms, context)
    end
  end

end
