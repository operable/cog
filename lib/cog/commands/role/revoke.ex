defmodule Cog.Commands.Role.Revoke do
  alias Cog.Repository.Roles
  alias Cog.Repository.Groups

  alias Cog.Models.Role

  require Cog.Commands.Helpers, as: Helpers

  Helpers.usage """
  Revoke a role from a group.

  USAGE
    role revoke [FLAGS] <role> <group>

  FLAGS
    -h, --help  Display this usage info

  ARGS
    role   The name of the role to revoke
    group  The name of the group to revoke the role from

  EXAMPLE

    role revoke admin-role dev-group

  """

  def revoke(%{options: %{"help" => true}}, _args),
    do: show_usage
  def revoke(_req, [role, group]) when is_binary(role) and is_binary(group) do
    case Roles.by_name(role) do
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
  end
  def revoke(_req, [_, _]),
    do: {:error, :wrong_type}
  def revoke(_req, []),
    do: {:error, {:not_enough_args, 2}}
  def revoke(_req, [_]),
    do: {:error, {:not_enough_args, 2}}
  def revoke(_req, _),
    do: {:error, {:too_many_args, 2}}

end
