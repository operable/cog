defmodule Cog.Commands.Group.Info do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "group-info"

  require Cog.Commands.Helpers, as: Helpers
  alias Cog.Commands.Group
  alias Cog.Repository.Groups

  @description "Get info about a user group"

  @arguments "<group-name>"

  @output_description "Returns the serialized group"

  @output_example """
  [
    {
      "roles": [
        {
          "name": "deploy",
          "id": "85c8d788-b368-472c-a83c-fd175d8c4c35"
        }
      ],
      "name": "engineering",
      "members": [
        {
          "username": "vanstee",
          "last_name": "Van Stee",
          "id": "7cb7fba2-ea65-46a0-a8af-bea71df1ac00",
          "first_name": "Patrick",
          "email_address": "patrick@operable.io"
        }
      ],
      "id": "0640f71f-3c1b-4d47-8b8b-c8765b115872"
    }
  ]
  """

  permission "manage_groups"

  rule ~s(when command is #{Cog.Util.Misc.embedded_bundle}:group-info must have #{Cog.Util.Misc.embedded_bundle}:manage_groups)

  def handle_message(req, state) do
    result = case Helpers.get_args(req.args, 1) do
      {:ok, [group_name]} ->
        case Groups.by_name(group_name) do
          {:ok, group} ->
            {:ok, "group-info", group}
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
end
