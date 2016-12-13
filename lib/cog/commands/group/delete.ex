defmodule Cog.Commands.Group.Delete do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "group-delete"

  require Cog.Commands.Helpers, as: Helpers
  alias Cog.Commands.Group
  alias Cog.Repository.Groups

  @description "Deletes user groups"

  @arguments "<group-name>"

  @output_description "Returns the serialized group that was just deleted"

  @output_example """
  [
    {
      "roles": [],
      "name": "ops",
      "members": [],
      "id": "e47cced6-0f7b-4e11-8c06-bb8db6f30147"
    }
  ]
  """

  permission "manage_groups"

  rule ~s(when command is #{Cog.Util.Misc.embedded_bundle}:group-delete must have #{Cog.Util.Misc.embedded_bundle}:manage_groups)

  def handle_message(req, state) do
    result = case Helpers.get_args(req.args, 1) do
      {:ok, [group_name]} ->
        case Groups.by_name(group_name) do
          {:ok, group} ->
            delete(group)
          {:error, :not_found} ->
            {:error, {:resource_not_found, "user group", group_name}}
        end
      error ->
        error
    end

    case result do
      {:ok, template, data} ->
        {:reply, req.reply_to, template, data, state}
      {:error, err} ->
        {:error, req.reply_to, Group.error(err), state}
    end
  end

  defp delete(group) do
    case Groups.delete(group) do
      {:ok, _deleted} ->
        {:ok, "user-group-delete", group}
      {:error, changeset} ->
        {:error, {:db_errors, changeset.errors}}
    end
  end
end
