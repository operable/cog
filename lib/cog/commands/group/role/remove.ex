defmodule Cog.Commands.Group.Role.Remove do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "group-role-remove"

  require Cog.Commands.Helpers, as: Helpers
  alias Cog.Commands.Group
  alias Cog.V1.GroupView
  alias Cog.Repository.Groups

  @description "Remove roles from user groups"

  @arguments "<group-name> <role-name ...>"

  @output_description "Returns the serialized group without the removed role"

  @output_example """
  [
    {
      "roles": [],
      "name": "engineering",
      "members": [],
      "id": "0640f71f-3c1b-4d47-8b8b-c8765b115872"
    }
  ]
  """

  permission "manage_groups"

  rule ~s(when command is #{Cog.Util.Misc.embedded_bundle}:group-role-remove must have #{Cog.Util.Misc.embedded_bundle}:manage_groups)

  def handle_message(req, state) do
    result = case Helpers.get_args(req.args, min: 2) do
      {:ok, [group_name | role_names]} ->
        case remove(group_name, role_names) do
          {:ok, group} ->
            data = GroupView.render("command.json", %{group: group})
            {:ok, "group-role-remove", Map.put(data, :roles_removed, role_names)}
          {:error, {:not_found, {kind, bad_names}}} ->
            {:error, {:resource_not_found, kind, Enum.join(bad_names, ", ")}}
          {:error, error} ->
            {:error, {:db_errors, error}}
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

  defp remove(group_name, role_names) do
    case Groups.by_name(group_name) do
      {:ok, group} ->
        Groups.manage_membership(group, %{"members" => %{"roles" => %{"remove" => role_names}}})
      {:error, :not_found} ->
        {:error, {:resource_not_found, "user group", group_name}}
    end
  end
end
