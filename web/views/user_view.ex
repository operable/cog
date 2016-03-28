defmodule Cog.V1.UserView do
  use Cog.Web, :view

  def render("user.json", %{user: user}) do
    %{id: user.id,
      username: user.username,
      first_name: user.first_name,
      last_name: user.last_name,
      email_address: user.email_address,
      groups: render_groups(user.group_memberships)}
  end

  def render("index.json", %{users: users}) do
    %{users: render_many(users, __MODULE__, "user.json")}
  end

  def render("show.json", %{user: user}) do
    %{user: render_one(user, __MODULE__, "user.json")}
  end

  defp render_groups(groups) when is_list(groups) do
    Enum.map(groups, fn(group_mem) ->
        %{id: group_mem.group.id,
          name: group_mem.group.name}
    end)
  end
  defp render_groups(_), do: []

end
