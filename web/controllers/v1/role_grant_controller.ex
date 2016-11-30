defmodule Cog.V1.RoleGrantController do
  use Cog.Web, :controller

  alias Cog.Repository.Groups
  alias Cog.Repo

  plug Cog.Plug.Authentication

  plug Cog.Plug.Authorization, [permission: "#{Cog.Util.Misc.embedded_bundle}:manage_groups"]

  plug :put_view, Cog.V1.RoleView

  def manage_group_roles(conn, %{"roles" => role_spec}=params) do
    result = params
    |> Map.put("members", prep_role_spec(role_spec))
    |> Map.delete("roles")
    |> Groups.manage_membership()

    case result do
      {:ok, group} ->
        # TODO: We should probably be handling preloads in the repository.
        # Because we manage roles through the group repository we get a group
        # back. I didn't want to add a bunch of unnecessary info to every call
        # to the group repository just to render roles here. So for now, we'll
        # just do the preload here.
        roles = Repo.preload(group, [roles: [permissions: :bundle]])
                |> Map.get(:roles)
        render(conn, "index.json", roles: roles)
      {:error, {:not_found, {"roles", names}}} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Cannot find one or more specified roles: #{Enum.join(names, ", ")}"})
      {:error, {:permanent_role_grant, role_name, group_name}} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Cannot remove '#{role_name}' role from '#{group_name}' group"})
    end
  end

  # Cog.Repository.Groups.manage_membership/1 expects the action to be
  # "add" or "remove", but cog-api sends "grant" or "revoke". We should
  # probably standardize on one or the other, but for now, and to avoid
  # breaking apps that call the api, we'll just support all 4 actions.
  defp prep_role_spec(%{"grant" => roles}),
    do: %{"roles" => %{"add" => roles}}
  defp prep_role_spec(%{"revoke" => roles}),
    do: %{"roles" => %{"remove" => roles}}
  defp prep_role_spec(%{"add" => roles}),
    do: %{"roles" => %{"add" => roles}}
  defp prep_role_spec(%{"remove" => roles}),
    do: %{"roles" => %{"remove" => roles}}

end
