defmodule Cog.Commands.Role.Delete do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "role-delete"

  alias Cog.Repository.Roles
  alias Cog.Models.Role
  alias Cog.Commands
  alias Cog.V1.RoleView

  @description "Delete a role"

  @long_description """
  Note that the special `cog-admin` role cannot
  be deleted.
  """

  @arguments "<name>"

  @examples """
  Delete a role named ops:

    role delete ops
  """

  @output_description "Returns the serialized role that was deleted"

  @output_example """
  [
    {
      "permissions": [],
      "name": "admin",
      "id": "6eaf55ca-0268-463a-b6bc-3eab4d1c2346"
    }
  ]
  """

  permission "manage_roles"

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:role-delete must have #{Cog.Util.Misc.embedded_bundle}:manage_roles"

  def handle_message(req = %{args: [role]}, state) when is_binary(role) do
    result = case Roles.by_name(role) do
      %Role{}=role ->
        with {:ok, _} <- Roles.delete(role),
          do: {:ok, "role-delete", RoleView.render("show.json", %{role: role})[:role]}
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
  def handle_message(req = %{args: [_]}, state),
    do: {:error, req.reply_to, Commands.Role.error(:wrong_type), state}
  def handle_message(req = %{args: []}, state),
    do: {:error, req.reply_to, Commands.Role.error({:not_enough_args, 1}), state}
  def handle_message(req, state),
    do: {:error, req.reply_to, Commands.Role.error({:too_many_args, 1}), state}
end
