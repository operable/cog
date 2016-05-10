defmodule Cog.V1.UserView do
  use Cog.Web, :view

  def render("user.json", %{user: user}) do
    %{id: user.id,
      username: user.username,
      first_name: user.first_name,
      last_name: user.last_name,
      email_address: user.email_address,
      groups: render_many(user.group_memberships, __MODULE__, "member.json", as: :member),
      chat_handles: render_many(user.chat_handles, Cog.V1.ChatHandleView, "show.json")}
  end
  def render("member.json", %{member: member}) do
    %{id: member.group.id,
      name: member.group.name,
      roles: render_many(member.group.roles, __MODULE__, "role.json", as: :role)}
  end
  def render("role.json", %{role: role}) do
    %{id: role.id,
      name: role.name,
      permissions: render_many(role.permissions, Cog.V1.PermissionView, "permission.json")}
  end

  def render("index.json", %{users: users}) do
    users = users |> preload_associations
    %{users: render_many(users, __MODULE__, "user.json")}
  end

  def render("show.json", %{user: user}) do
    user = user |> preload_associations
    %{user: render_one(user, __MODULE__, "user.json")}
  end


  defp preload_associations(user) do
    Cog.Repo.preload(user, [
      chat_handles: [:chat_provider],
      direct_group_memberships: [roles: [permissions:
          :namespace]]
    ])
  end
end
