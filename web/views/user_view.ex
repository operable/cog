defmodule Cog.V1.UserView do
  use Cog.Web, :view

  def render("user.json", %{user: user}) do
    %{id: user.id,
      username: user.username,
      first_name: user.first_name,
      last_name: user.last_name,
      email_address: user.email_address,
      groups: render_groups(user.group_memberships),
      roles: render_roles(user.group_memberships)}
  end
  def render("role.json", %{role: role}) do
    %{id: role.id,
      name: role.name,
      permissions: render_many(role.permissions, Cog.V1.PermissionView, "permission.json")}
  end

  def render("index.json", %{users: users}) do
    %{users: render_many(users, __MODULE__, "user.json")}
  end

  def render("show.json", %{user: user}) do
    %{user: render_one(user, __MODULE__, "user.json")}
  end

  defp render_groups(groups) do
    Enum.map(groups, fn(group_mem) ->
        %{id: group_mem.group.id,
          name: group_mem.group.name}
    end)
  end

  defp render_roles(members) do
    Enum.flat_map(members, fn(member) ->
          render_many(member.group.roles, __MODULE__, "role.json", as: :role)
    end)
  end
end
