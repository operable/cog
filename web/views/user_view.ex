defmodule Cog.V1.UserView do
  use Cog.Web, :view

  def render("user.json", %{user: user}) do
    %{id: user.id,
      username: user.username,
      first_name: user.first_name,
      last_name: user.last_name,
      email_address: user.email_address,
      groups: render_many(user.group_memberships, __MODULE__, "group.json", as: :group),
      chat_handles: render_many(user.chat_handles, Cog.V1.ChatHandleView, "show.json")}
  end
  def render("group.json", %{group: group}) do
    %{id: group.id,
      name: group.name,
      roles: render_many(group.roles, __MODULE__, "role.json", as: :role)}
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
end
