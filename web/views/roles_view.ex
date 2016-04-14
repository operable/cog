defmodule Cog.V1.RoleView do
  use Cog.Web, :view

  def render("role.json", %{role: role}=resource) do
    %{id: role.id,
      name: role.name,
      permissions: render_many(role.permissions, Cog.V1.PermissionView, "permission.json", as: :permission),
    }
    |> Map.merge(render_includes(resource, role))
  end

  def render("grant.json", %{grant: grant}) do
    # The group/role/user/permission relationship is
    # typically a user belongs to group(s), a group
    # has role(s) and a role has permission(s). As
    # a result, displaying the group_grants under
    # roless is an atypical flow, so this structure
    # is local to the RolesView.
    %{id: grant.group.id,
      name: grant.group.name
    }
  end
  def render("grant.json", _), do: ""

  def render("index.json", %{roles: roles}) do
    %{roles: render_many(roles, __MODULE__, "role.json", as: :role, include: [:group_grants])}
  end

  def render("show.json", %{role: role}) do
    %{role: render_one(role, __MODULE__, "role.json", as: :role, include: [:group_grants])}
  end

  defp render_includes(resource, role) do
    Map.get(resource, :include, [])
    |> Enum.reduce(%{}, fn(field, reply) -> 
      case render_include(field, role) do
        nil -> reply
        {key, value} -> Map.put(reply, key, value)
      end
    end)
  end

  defp render_include(:group_grants, role) do
    value = Map.fetch!(role, :group_grants)
    case Ecto.assoc_loaded?(value) do
      true ->
        {:groups, render_many(value, __MODULE__, "grant.json", as: :grant)}
      false ->
        nil
    end
  end
end
