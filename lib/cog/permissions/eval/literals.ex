defimpl Cog.Eval, for: [Piper.Permissions.Ast.Integer,
                         Piper.Permissions.Ast.Float,
                         Piper.Permissions.Ast.String,
                         Piper.Permissions.Ast.Bool,
                         Piper.Permissions.Ast.Regex,
                         Piper.Permissions.Ast.List] do

  alias Piper.Permissions.Ast

  def value_of(%Ast.Integer{value: value}, context) do
    {value, context}
  end
  def value_of(%Ast.Float{value: value}, context) do
    {value, context}
  end
  def value_of(%Ast.String{value: value}, context) do
    {value, context}
  end
  def value_of(%Ast.Bool{value: value}, context) do
    {value, context}
  end
  def value_of(%Ast.Regex{value: value}, context) do
    {value, context}
  end
  def value_of(%Ast.List{values: values}, context) do
    {values, context}
  end
end
