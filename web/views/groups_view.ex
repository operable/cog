defmodule Cog.V1.GroupView do
  use Cog.Web, :view

  def render("group.json", %{group: group}) do
    %{id: group.id,
      name: group.name,
      members: %{roles: render_roles(group.roles),
                 users: render_users(group.direct_user_members),
                 groups: render_groups(group.direct_group_members)}
    }
  end

  def render("index.json", %{groups: groups}) do
    %{groups: render_many(groups, __MODULE__, "group.json")}
  end

  def render("show.json", %{group: group}) do
    %{group: render_one(group, __MODULE__, "group.json")}
  end

  def render("command.json", %{group: group}) do
    %{id: group.id,
      name: group.name,
      roles: render_roles(group.roles),
      members: render_users(group.direct_user_members)}
  end

  defp render_roles(roles) when is_list(roles) do
    Enum.map(roles, fn(role) ->
        %{id: role.id,
          name: role.name}
    end)
  end
  defp render_roles(_), do: []

  defp render_users(users) when is_list(users) do
    Enum.map(users, fn(user) ->
        %{id: user.id,
          email_address: user.email_address,
          first_name: user.first_name,
          last_name: user.last_name,
          username: user.username}
    end)
  end
  defp render_users(_), do: []

  defp render_groups(groups) when is_list(groups) do
    Enum.map(groups, fn(group) ->
        %{id: group.id,
          name: group.name}
    end)
  end
  defp render_groups(_), do: []

end
