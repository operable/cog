defmodule Cog.Commands.AliasCreate do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "alias-create"

  alias Cog.Repo
  alias Cog.Models.UserCommandAlias
  require Cog.Commands.Helpers, as: Helpers

  @description "Create new aliases"

  @arguments "<name> <definition>"

  @examples """
  Create a new alias:

    alias create my-awesome-alias "echo \"My Awesome Alias\""
  """

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:alias-create allow"

  def handle_message(req, state) do
    case Helpers.get_args(req.args, 2) do
      {:ok, [alias_name, pipeline]} ->
        params = %{name: alias_name, pipeline: pipeline, user_id: req.user["id"]}
        changeset = UserCommandAlias.changeset(%UserCommandAlias{}, params)

        case Repo.insert(changeset) do
          {:ok, command_alias} ->
            {:reply, req.reply_to, "alias-create", Helpers.jsonify(command_alias), state}
          {:error, %{errors: errors}} ->
            {:error, req.reply_to, Helpers.error({:db_errors, errors}), state}
        end
      {:error, error} ->
        {:error, req.reply_to, Helpers.error(error), state}
    end
  end
end
