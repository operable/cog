defmodule Cog.Commands.Pipeline.Info do

  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "pipeline-info"

  alias Cog.Commands.Pipeline.Util
  alias Cog.Repository.PipelineHistory, as: HistoryRepo

  @description "Display command pipeline details"

  @arguments "id ..."

  # Allow any user to run info
  rule "when command is #{Cog.Util.Misc.embedded_bundle}:pipeline-info allow"

  def handle_message(%{args: ids} = req, state) do
    infos = ids
            |> Enum.reduce([], &pipeline_info/2)
            |> Enum.map(&Util.entry_to_map/1)
    {:reply, req.reply_to, "pipeline-info", infos, state}
  end

  defp pipeline_info(id, accum) do
    case HistoryRepo.by_short_id(id) do
      nil ->
        accum
      entry ->
        [entry|accum]
    end
  end

end
