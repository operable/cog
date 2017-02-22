defmodule Cog.Commands.Pipeline.Info do

  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "pipeline-info"

  alias Cog.Commands.Pipeline.Util
  alias Cog.Repository.PipelineHistory, as: HistoryRepo
  alias Cog.Repository.Users, as: UserRepo
  alias Cog.Models.User
  alias Cog.Repository.Permissions

  @description "Display command pipeline details"

  @arguments "id ..."

  # Allow any user to run info
  rule "when command is #{Cog.Util.Misc.embedded_bundle}:pipeline-info allow"

  # We need to lock down who can manage a user's pipelines to the owning
  # user and admins. We don't have a way to express that via rules currently
  # so we have to handle it within the command.
  permission "manage_user_pipeline"

  def handle_message(%{args: ids} = req, state) do
    infos = ids
            |> Enum.reduce([], pipeline_info_fn(req))
            |> Enum.map(&Util.entry_to_map/1)
    {:reply, req.reply_to, "pipeline-info", infos, state}
  end

  defp pipeline_info_fn(req) do
    # Wrapping the permission checking bits up in a closure
    # so we only make the request for the user and perm once.
    {:ok, req_user} = UserRepo.by_username(req.user["username"])
    perm = Permissions.by_name("operable:manage_user_pipeline")
    has_perm? = User.has_permission(req_user, perm)

    fn(id, accum) ->
      case HistoryRepo.by_short_id(id) do
        nil ->
          accum
        entry ->
          # If the user has the manage_user_pipeline perm or owns
          # the pipeline, return it. Otherwise just ignore it.
          if has_perm? || entry.user.id == req_user.id do
            [entry|accum]
          else
            accum
          end
      end
    end
  end

end
