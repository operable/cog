defmodule Cog.Commands.Role.Rename do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "role-rename"

  alias Cog.Commands
  alias Cog.Models.Role
  alias Cog.Repository.Roles

  @description "Rename a role"

  @arguments "<name> <new-name>"

  @examples """
  Rename a role from aws-admin to cloud-commander:

    role rename aws-admin cloud-commander
  """

  @output_description "Returns the serialized role including an old name attribute"

  @output_example """
  [
    {
      "permissions": [],
      "old_name": "administration",
      "name": "admin",
      "id": "b711d91a-dcbe-4adc-862f-ea9144438955"
    }
  ]
  """

  permission "manage_roles"

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:role-rename must have #{Cog.Util.Misc.embedded_bundle}:manage_roles"

  def handle_message(req = %{args: [old, new]}, state) when is_binary(old) and is_binary(new) do
    result = case Roles.by_name(old) do
      %Role{}=role ->
        case Roles.rename(role, new) do
          {:ok, role} ->
            rendered = Cog.V1.RoleView.render("show.json", %{role: role})
            {:ok, "role-rename", Map.put(rendered[:role], :old_name, old)}
          {:error, _}=error ->
            error
        end
      nil ->
        {:error, {:resource_not_found, "role", old}}
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
