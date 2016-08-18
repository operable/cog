defimpl Cog.Eval, for: Piper.Permissions.Ast.ContainExpr do

  alias Cog.Eval
  alias Cog.Permissions.Context
  alias Piper.Permissions.Ast

  def value_of(%Ast.ContainExpr{lhs_agg: false, left: lhs, right: rhs}, context) do
    {lhsv, context} = Eval.value_of(lhs, context)
    {rhsv, context} = Eval.value_of(rhs, context)
    member?(lhsv, rhsv, context)
  end
  def value_of(%Ast.ContainExpr{left: lhs, right: rhs}, context) do
    case Eval.value_of(lhs, context) do
      {{_, []}, context} ->
        {false, context}
      {{_, %{}}, context} ->
        {false, context}
      {{_, nil}, context} ->
        {false, context}
      {{type, lhsv}, context} ->
        lhsv = prepare(type, lhsv)
        {rhsv, context} = Eval.value_of(rhs, context)
        intersects?(lhsv, rhsv, context, type)
    end
  end

  defp prepare({:arg, _}, lhsv) do
    for {arg, index} <- Enum.with_index(lhsv), do: {index, arg}
  end
  defp prepare({:option, _}, lhsv) do
    Map.to_list(lhsv)
  end

  defp intersects?([], _rhsv, context, {_, :all}) do
    {true, context}
  end
  defp intersects?(_rhsv, [], context, {_, :all}) do
    {false, context}
  end
  defp intersects?(_lhsv, [], context, {_, :any}) do
    {false, context}
  end
  defp intersects?(lhsv, [rhs|t], context, {type, :any}) do
    {rhsv, context} = Eval.value_of(rhs, context)
    {context, updated} = Enum.reduce(lhsv, {context, []},
      fn({key, value}, {context, acc}) ->
        if expr_match?(value, rhsv) == true do
          {Context.add_match(context, type, key), acc}
        else
          {context, acc ++ [{key, value}]}
        end
      end)
    if updated == lhsv do
      intersects?(lhsv, t, context, {type, :any})
    else
      {true, context}
    end
  end
  defp intersects?(lhsv, [rhs|t], context, {type, :all}) do
    {rhsv, context} = Eval.value_of(rhs, context)
    {context, lhsv} = Enum.reduce(lhsv, {context, []},
      fn({key, value}, {context, acc}) ->
        if expr_match?(value, rhsv) == true do
          {Context.add_match(context, type, key), acc}
        else
          {context, acc ++ [{key, value}]}
        end
      end)
    intersects?(lhsv, t, context, {type, :all})
  end

  defp member?(_lhsv, [], context) do
    {false, context}
  end
  defp member?({{:arg, index}, lhsv}=lhs, [rhs|t], context) do
    {rhsv, context} = Eval.value_of(rhs, context)
    case expr_match?(lhsv, rhsv) do
      true ->
        {true, Context.add_match(context, :arg, index)}
      false ->
        member?(lhs, t, context)
    end
  end
  defp member?({{:option, name}, lhsv}=lhs, [rhs|t], context) do
    {rhsv, context} = Eval.value_of(rhs, context)
    case expr_match?(lhsv, rhsv) do
      true ->
        {true, Context.add_match(context, :option, name)}
      false ->
        member?(lhs, t, context)
    end
  end

  defp expr_match?(lhsv, %Regex{}=rhsv) do
    Regex.match?(rhsv, "#{lhsv}")
  end
  defp expr_match?(lhsv, rhsv) do
    lhsv == rhsv
  end
end
