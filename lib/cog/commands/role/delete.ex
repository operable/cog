defmodule Cog.Commands.Role.Delete do
  require Cog.Commands.Helpers, as: Helpers

  alias Cog.Repository.Roles
  alias Cog.Models.Role

  alias Cog.V1.RoleView

  Helpers.usage """
  Delete a role.

  Note that the special `cog-admin` role cannot be deleted.

  USAGE
    role delete [FLAGS] <name>

  FLAGS
    -h, --help  Display this usage info

  ARGS
    name     The role to delete

  EXAMPLE

    role delete foo

  """

  def delete(%{options: %{"help" => true}}, _args),
    do: show_usage
  def delete(_req, [role]) when is_binary(role) do
    case Roles.by_name(role) do
      %Role{}=role ->
        with {:ok, _} <- Roles.delete(role),
          do: {:ok, "role-delete", RoleView.render("show.json", %{role: role})[:role]}
      nil ->
        {:error, {:resource_not_found, "role", role}}
    end
  end
  def delete(_req, [_]),
    do: {:error, :wrong_type}
  def delete(_req, []),
    do: {:error, {:not_enough_args, 1}}
  def delete(_req, _),
    do: {:error, {:too_many_args, 1}}

end
