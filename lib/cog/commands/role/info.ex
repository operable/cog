defmodule Cog.Commands.Role.Info do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "role-info"

  alias Cog.Repository.Roles
  alias Cog.Models.Role
  alias Cog.Commands

  @description "Get detailed information about a role"

  @arguments "<name>"

  @examples """
  View info for the admin role:

    role info admin
  """

  @output_description "Returns the serialized role"

  @output_example """
  [
    {
      "permissions": [],
      "name": "admin",
      "id": "b711d91a-dcbe-4adc-862f-ea9144438955"
    }
  ]
  """

  permission "manage_roles"

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:role-info must have #{Cog.Util.Misc.embedded_bundle}:manage_roles"

  def handle_message(req = %{args: [name]}, state) when is_binary(name) do
    result = case Roles.by_name(name) do
      %Role{}=role ->
        rendered = Cog.V1.RoleView.render("show.json", %{role: role})
        {:ok, "role-info", rendered[:role]}
      nil ->
        {:error, {:resource_not_found, "role", name}}
    end

    case result do
      {:ok, template, data} ->
        {:reply, req.reply_to, template, data, state}
      {:error, err} ->
        {:error, req.reply_to, Commands.Role.error(err), state}
    end
  end
  def handle_message(req = %{args: [_]}, state),
    do: {:error, req.reply_to, Commands.Role.error(:wrong_type), state}
  def handle_message(req = %{args: []}, state),
    do: {:error, req.reply_to, Commands.Role.error({:not_enough_args, 1}), state}
  def handle_message(req, state),
    do: {:error, req.reply_to, Commands.Role.error({:too_many_args, 1}), state}
end
