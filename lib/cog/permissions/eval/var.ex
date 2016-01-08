defimpl Cog.Eval, for: Piper.Permissions.Ast.Var do

  alias Piper.Permissions.Ast

  def value_of(%Ast.Var{name: "command"}, context) do
    {context.command, context}
  end

end
