defmodule Cog.Commands.Alias.Create do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "alias-create"

  alias Cog.Repo
  alias Cog.Models.UserCommandAlias

  alias Cog.Commands.Alias
  alias Cog.Commands.Helpers

  @description "Create new aliases. Subcommand for alias."

  @arguments "<alias-name> <alias-definition>"

  @examples """
  Creating an alias:

    alias create my-awesome-alias "echo \"My awesome alias\""
  """

  @output_description "Returns a serialized alias upon successful creation"

  @output_example """
  [
    {
      "visibility": "user",
      "pipeline": "echo \"My awesome alias\"",
      "name": "my-awesome-alias"
    }
  ]
  """

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:alias-create allow"

  def handle_message(req, state) do
    result = case Helpers.get_args(req.args, 2) do
      {:ok, [alias_name, pipeline]} ->
        params = %{name: alias_name, pipeline: pipeline, user_id: req.user["id"]}
        changeset = UserCommandAlias.changeset(%UserCommandAlias{}, params)

        case Repo.insert(changeset) do
          {:ok, command_alias} ->
            {:ok, "alias-create", Helpers.jsonify(command_alias)}
          {:error, %{errors: errors}} ->
            {:error, {:db_errors, errors}}
        end
      error ->
        error
    end

    case result do
      {:ok, template, data} ->
        {:reply, req.reply_to, template, data, state}
      {:error, err} ->
        {:error, req.reply_to, Alias.error(err), state}
    end
  end
end
