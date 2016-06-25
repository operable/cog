defmodule Cog.Commands.Role.Grant do
  alias Cog.Repository.Roles
  alias Cog.Repository.Groups

  alias Cog.Models.Role

  require Cog.Commands.Helpers, as: Helpers

  Helpers.usage """
  Grant a role to a group.

  USAGE
    role grant [FLAGS] <role> <group>

  FLAGS
    -h, --help  Display this usage info

  ARGS
    role   The name of the role to grant.
    group  The name of the group to grant the role to

  EXAMPLE

    role grant admin-role dev-group

  """

  def grant(%{options: %{"help" => true}}, _args),
    do: show_usage
  def grant(_req, [role, group]) when is_binary(role) and is_binary(group) do
    case Roles.by_name(role) do
      %Role{}=role ->
        case Groups.by_name(group) do
          {:ok, group} ->
            :ok = Groups.grant(group, role)
            role  = Cog.V1.RoleView.render("show.json", %{role: role})
            group = Cog.V1.GroupView.render("show.json", %{group: group})
            {:ok, "role-grant", Map.merge(role, group)}
          {:error, :not_found} ->
            {:error, {:resource_not_found, "group", group}}
        end
      nil ->
        {:error, {:resource_not_found, "role", role}}
    end
  end
  def grant(_req, [_, _]),
    do: {:error, :wrong_type}
  def grant(_req, []),
    do: {:error, {:not_enough_args, 2}}
  def grant(_req, [_]),
    do: {:error, {:not_enough_args, 2}}
  def grant(_req, _),
    do: {:error, {:too_many_args, 2}}

end
