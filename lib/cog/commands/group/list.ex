defmodule Cog.Commands.Group.List do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "group-list"

  require Cog.Commands.Helpers, as: Helpers
  alias Cog.Repository.Groups

  @description "Lists user groups"

  @output_description "Returns serialized groups containing roles and members"

  @output_example """
  [
    {
      "roles": [
        {
          "name": "cog-admin",
          "id": "87ae871e-2835-4241-b6de-1fa43e554503"
        }
      ],
      "name": "cog-admin",
      "members": [
        {
          "username": "admin",
          "last_name": "Administrator",
          "id": "45622ead-bade-4a81-9aaa-558d5eacbe7b",
          "first_name": "Cog",
          "email_address": "cog@localhost"
        },
        {
          "username": "vanstee",
          "last_name": "Van Stee",
          "id": "7cb7fba2-ea65-46a0-a8af-bea71df1ac00",
          "first_name": "Patrick",
          "email_address": "patrick@operable.io"
        }
      ],
      "id": "6e4ac31b-fe7a-4f50-a265-258194e2631d"
    }
  ]
  """

  option "verbose", type: "bool", short: "v"

  rule ~s(when command is #{Cog.Util.Misc.embedded_bundle}:group-list must have #{Cog.Util.Misc.embedded_bundle}:manage_groups)

  def handle_message(req, state) do
    case Groups.all do
      [] ->
        {:reply, req.reply_to, "Currently, there are no groups in the system.", state}
      groups ->
        {:reply, req.reply_to, get_template(req.options), groups, state}
    end
  end

  defp get_template(options) do
    if Helpers.flag?(options, "verbose") do
      "user-group-list-verbose"
    else
      "user-group-list"
    end
  end
end
