defmodule Cog.Commands.Pipeline.Kill do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "pipeline-kill"

  alias Cog.Commands.Pipeline.Util
  alias Cog.Pipeline
  alias Cog.Repository.PipelineHistory, as: HistoryRepo

  @description "Abort a running pipeline"

  @arguments "id ..."

  # Allow any user to run ps
  rule "when command is #{Cog.Util.Misc.embedded_bundle}:pipeline-kill allow"

  def handle_message(%{args: ids} = req, state) do
    killed = Enum.reduce(ids, [], &kill_pipeline/2)
    killed_text = case killed do
                    [] ->
                      "none"
                    _ ->
                      Enum.join(killed, ",")
                  end
    results = %{killed: killed,
                killed_text: killed_text}
    {:reply, req.reply_to, "pipeline-kill", results, state}
  end

  defp kill_pipeline(id, killed) do
    case HistoryRepo.by_short_id(id, "finished") do
      nil ->
        killed
      entry ->
        if Process.alive?(entry.pid) do
          Pipeline.teardown(entry.pid)
          [Util.short_id(entry.id)|killed]
        else
          killed
        end
    end
  end

end
