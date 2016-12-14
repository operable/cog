defmodule Cog.Commands.Role.Revoke do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "role-revoke"

  alias Cog.Commands
  alias Cog.Models.Role
  alias Cog.Repository.{Roles, Groups}

  @description "Revoke a role from a group"

  @arguments "<role> <group>"

  @examples """
  Revoke the admin role from the ops group"

    role revoke admin ops
  """

  @output_description "Returns the serialized role and group that the role was revoked from"

  @output_example """
  [
    {
      "role": {
        "permissions": [],
        "name": "admin",
        "id": "b711d91a-dcbe-4adc-862f-ea9144438955"
      },
      "group": {
        "name": "ops",
        "members": {
          "users": [],
          "roles": [
            {
              "name": "admin",
              "id": "b711d91a-dcbe-4adc-862f-ea9144438955"
            }
          ],
          "groups": []
        },
        "id": "2c9c8f77-6521-4b0c-b5cb-25548f83dcf2"
      }
    }
  ]
  """

  permission "manage_roles"
  permission "manage_groups"

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:role-revoke must have #{Cog.Util.Misc.embedded_bundle}:manage_roles"
  rule "when command is #{Cog.Util.Misc.embedded_bundle}:role-revoke must have #{Cog.Util.Misc.embedded_bundle}:manage_roles"

  def handle_message(req = %{args: [role, group]}, state) when is_binary(role) and is_binary(group) do
    result = case Roles.by_name(role) do
      %Role{}=role ->
        case Groups.by_name(group) do
          {:ok, group} ->
            with(:ok <- Groups.revoke(group, role)) do
              role  = Cog.V1.RoleView.render("show.json", %{role: role})
              group = Cog.V1.GroupView.render("show.json", %{group: group})
              {:ok, "role-revoke", Map.merge(role, group)}
            end
          {:error, :not_found} ->
            {:error, {:resource_not_found, "group", group}}
        end
      nil ->
        {:error, {:resource_not_found, "role", role}}
    end

    case result do
      {:ok, template, data} ->
        {:reply, req.reply_to, template, data, state}
      {:error, err} ->
        {:error, req.reply_to, Commands.Role.error(err), state}
    end
  end
  def handle_message(req = %{args: [_, _]}, state),
    do: {:error, req.reply_to, Commands.Role.error(:wrong_type), state}
  def handle_message(req = %{args: args}, state) when length(args) < 2,
    do: {:error, req.reply_to, Commands.Role.error({:not_enough_args, 2}), state}
  def handle_message(req, state),
    do: {:error, req.reply_to, Commands.Role.error({:too_many_args, 2}), state}
end
