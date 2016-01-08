defimpl Cog.Eval, for: Piper.Permissions.Ast.ConditionalExpr do

  alias Cog.Eval
  alias Piper.Permissions.Ast

  def value_of(%Ast.ConditionalExpr{op: op, left: lhs, right: rhs}, context) do
    f = operator(op)
    {lhsv, context} = Eval.value_of(lhs, context)
    {rhsv, context} = Eval.value_of(rhs, context)
    {f.(lhsv, rhsv), context}
  end

  defp operator(:and) do
    &Kernel.and/2
  end
  defp operator(:or) do
    &Kernel.or/2
  end

end
