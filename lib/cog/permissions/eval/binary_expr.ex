defimpl Cog.Eval, for: Piper.Permissions.Ast.BinaryExpr do

  alias Cog.Eval
  alias Cog.Permissions.Context
  alias Piper.Permissions.Ast

  def value_of(%Ast.BinaryExpr{op: op, left: lhs, right: rhs}, context) do
    comparator = comparison_type_to_function(op)
    {lhsv, context} = Eval.value_of(lhs, context)
    {rhsv, context} = Eval.value_of(rhs, context)
    compare(lhsv, rhsv, comparator, context)
  end

  defp compare({{:arg, type}, lhsv}, rhsv, comparator, context) when type in [:any, :all] do
    lhsv = for {arg, index} <- Enum.with_index(lhsv), do: {index, arg}
    cog_and_compare(:arg, type, lhsv, rhsv, comparator, context)
  end
  defp compare({{:arg, index}, lhsv}, rhsv, comparator, context) do
    case comparator.(lhsv, rhsv) do
      true ->
        {true, Context.add_match(context, :arg, index)}
      false ->
        {false, context}
    end
  end
  defp compare({{:option, type}, lhsv}, rhsv, comparator, context) when type in [:any, :all] do
    cog_and_compare(:option, type, Map.to_list(lhsv), rhsv, comparator, context)
  end
  defp compare({{:option, name}, lhsv}, rhsv, comparator, context) do
    case comparator.(lhsv, rhsv) do
      true ->
        {true, Context.add_match(context, :option, name)}
      false ->
        {false, context}
    end
  end
  defp compare(lhsv, rhsv, comparator, context) do
    {comparator.(lhsv, rhsv), context}
  end

  defp cog_and_compare(_kind, :any, [], _rhsv, _comparator, context) do
    {false, context}
  end
  defp cog_and_compare(_kind, :all, [], _rhsv, _comparator, context) do
    {true, context}
  end
  defp cog_and_compare(kind, :all, [{name, value}|t], rhsv, comparator, context) do
    case comparator.(value, rhsv) do
      true ->
        cog_and_compare(kind, :all, t, rhsv, comparator, Context.add_match(context, kind, name))
      false ->
        {false, context}
    end
  end
  defp cog_and_compare(kind, :any, [{name, value}|t], rhsv, comparator, context) do
    case comparator.(value, rhsv) do
      true ->
        {true, Context.add_match(context, :option, name)}
      false ->
        cog_and_compare(kind, :any, t, rhsv, comparator, context)
    end
  end

  defp comparison_type_to_function(:is) do
    fn(lhs, %Regex{}=rhs) ->
        Regex.match?(rhs, lhs)
      (lhs, rhs) ->
        lhs == rhs
    end
  end
  defp comparison_type_to_function(:gt), do: &Kernel.>/2
  defp comparison_type_to_function(:gte), do: &Kernel.>=/2
  defp comparison_type_to_function(:lt), do: &Kernel.</2
  defp comparison_type_to_function(:lte), do: &Kernel.<=/2
  defp comparison_type_to_function(:equiv), do: &Kernel.==/2
  defp comparison_type_to_function(:not_equiv), do: &Kernel.!=/2
  defp comparison_type_to_function(:matches) do
    fn(nil, _) ->
        false
      (value, %Regex{}=regex) ->
        Regex.match?(regex, value)
    end
  end
  defp comparison_type_to_function(:not_matches) do
    fn(nil, _) ->
        false
      (value, %Regex{}=regex) ->
        Regex.match?(regex, value) == false
    end
  end
  defp comparison_type_to_function(:with), do: &Kernel.and/2

end
