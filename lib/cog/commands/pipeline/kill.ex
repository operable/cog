defmodule Cog.Commands.Pipeline.Kill do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "pipeline-kill"

  alias Cog.Commands.Pipeline.Util
  alias Cog.Pipeline
  alias Cog.Repository.PipelineHistory, as: HistoryRepo
  alias Cog.Repository.Users, as: UserRepo
  alias Cog.Models.User
  alias Cog.Repository.Permissions

  @description "Abort a running pipeline"

  @arguments "id ..."

  # Allow any user to run ps
  rule "when command is #{Cog.Util.Misc.embedded_bundle}:pipeline-kill allow"

  def handle_message(%{args: ids} = req, state) do
    killed = Enum.reduce(ids, [], kill_pipeline_fn(req))
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

  defp kill_pipeline_fn(req) do
    # Wrapping the permission checking bits up in a closure
    # so we only make the request for the user and perm once.
    {:ok, req_user} = UserRepo.by_username(req.user["username"])
    perm = Permissions.by_name("operable:manage_user_pipeline")
    has_perm? = User.has_permission(req_user, perm)

    can_kill? = fn(entry) ->
      Process.alive?(entry.pid) && (has_perm? || entry.user.id == req_user.id)
    end

    fn(id, killed) ->
      case HistoryRepo.by_short_id(id, "finished") do
        nil ->
          killed
        entry ->
          if can_kill?.(entry) do
            Pipeline.teardown(entry.pid)
            [Util.short_id(entry.id)|killed]
          else
            killed
          end
      end
    end
  end
end
