defimpl String.Chars, for: Cog.Pipeline.ExecutionStage do
  alias Cog.Pipeline.ExecutionStage

  def to_string(%ExecutionStage{request_id: id, index: index, invocation: invocation}) do
    "#Cog.Pipeline.ExecutionStage<request_id: #{id}, index: #{index}, invocation: #{invocation}>"
  end

end
