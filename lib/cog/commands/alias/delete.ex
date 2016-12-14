defmodule Cog.Commands.Alias.Delete do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "alias-delete"

  alias Cog.Repo
  require Cog.Commands.Helpers, as: Helpers

  @description "Removes an alias"

  @long_description """
  If a visibility is not passed the user visibility is first searched and then
  the site visibility.
  """

  @arguments "<alias-name>"

  @examples """
  Deleting an alias:

    alias delete my-awesome-alias
  """

  @output_description "Returns the serialized alias that was deleted"

  @output_example """
  [
    {
      "visibility": "user",
      "pipeline": "echo \\\"My Awesome Alias\\\"",
      "name": "my-awesome-alias"
    }
  ]
  """

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:alias-delete allow"

  def handle_message(req, state) do
    user_id = req.user["id"]

    result = case Helpers.get_args(req.args, 1) do
      {:ok, [alias]} ->
        case Helpers.get_command_alias(user_id, alias) do
          nil ->
            {:error, {:alias_not_found, alias}}
          command_alias ->
            case Repo.delete(command_alias) do
              {:ok, removed_alias} ->
                {:ok, "alias-delete", Helpers.jsonify(removed_alias)}
              {:error, %{errors: errors}} ->
                {:error, {:db_errors, errors}}
            end
        end
        error ->
          error
    end

    case result do
      {:ok, template, data} ->
        {:reply, req.reply_to, template, data, state}
      {:error, err} ->
        {:error, req.reply_to, Helpers.error(err), state}
    end
  end

end
