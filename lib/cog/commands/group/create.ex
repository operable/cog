defmodule Cog.Commands.Group.Create do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "group-create"

  require Cog.Commands.Helpers, as: Helpers
  alias Cog.Commands.Group
  alias Cog.Repository.Groups

  @description "Creates new user groups"

  @arguments "<group-name>"

  @output_description "Returns the newly created serialized group"

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

  rule ~s(when command is #{Cog.Util.Misc.embedded_bundle}:group-create must have #{Cog.Util.Misc.embedded_bundle}:manage_groups)

  def handle_message(req, state) do
    result = case Helpers.get_args(req.args, 1) do
      {:ok, [group_name]} ->
        case Groups.new(%{name: group_name}) do
          {:ok, group} ->
            {:ok, "user-group-create", group}
          {:error, changeset} ->
            {:error, {:db_errors, changeset.errors}}
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
end
