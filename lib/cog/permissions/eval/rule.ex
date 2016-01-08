defimpl Cog.Eval, for: Piper.Permissions.Ast.Rule do

  alias Cog.Eval
  alias Cog.Permissions.Context
  alias Piper.Permissions.Ast

  def value_of(%Ast.Rule{command_selector: cs, permission_selector: ps}, context) do
    context = Context.reset_matches(context)
    case Eval.value_of(cs, context) do
      {false, _context} ->
        :nomatch
      {true, context} ->
        {result, context} = Eval.value_of(ps, context)
        score = Enum.sum(Map.values(context.input_matches))
        {result, score}
    end
  end
end
