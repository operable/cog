defmodule Cog.V1.PermissionView do
  use Cog.Web, :view

  def render("permission.json", %{permission: permission}) do
    %{id: permission.id,
      name: permission.name,
      namespace: permission.namespace.name}
  end

  def render("index.json", %{permissions: permissions}) do
    %{permissions: render_many(permissions, __MODULE__, "permission.json")}
  end

  def render("show.json", %{permission: permission}) do
    %{permission: render_one(permission, __MODULE__, "permission.json")}
  end

end
