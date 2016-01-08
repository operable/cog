defimpl Cog.Eval, for: [Piper.Permissions.Ast.Arg,
                         Piper.Permissions.Ast.Option] do

  alias Piper.Permissions.Ast

  def value_of(%Ast.Arg{index: index}, context) when index in [:any, :all] do
    {{{:arg, index}, context.args}, context}
  end
  def value_of(%Ast.Arg{index: index}, context) when is_integer(index) do
    case length(context.args) <= index do
      true ->
        {{{:arg, index}, nil}, context}
      false ->
        {{{:arg, index}, Enum.at(context.args, index)}, context}
    end
  end
  def value_of(%Ast.Option{name: name}, context) when name in [:any, :all] do
    {{{:option, name}, context.options}, context}
  end
  def value_of(%Ast.Option{name: name}, context) when is_binary(name) do
    {{{:option, name}, Map.get(context.options, name)}, context}
  end

end

