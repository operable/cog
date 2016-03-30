defmodule Cog.V1.RoleView do
  use Cog.Web, :view

  def render("role.json", %{role: role}) do
    %{id: role.id,
      name: role.name,
      permissions: render_permissions(role.permissions)}
  end

  def render("index.json", %{roles: []}), do: %{roles: []}
  def render("index.json", %{roles: roles}) do
    %{roles: render_many(roles, __MODULE__, "role.json")}
  end

  def render("show.json", %{role: role}) do
    %{role: render_one(role, __MODULE__, "role.json")}
  end

  defp render_permissions(permissions) when is_list(permissions) do
    Enum.map(permissions, fn(permission) ->
        %{id: permission.id,
          name: permission.name,
          namespace: permission.namespace.name}
    end)
  end
  defp render_permissions(_), do: []

end
