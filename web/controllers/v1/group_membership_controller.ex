defmodule Cog.V1.GroupMembershipController do
  use Cog.Web, :controller

  alias Cog.Repository.Groups

  plug Cog.Plug.Authentication
  plug Cog.Plug.Authorization, permission: "#{Cog.embedded_bundle}:manage_groups"

  plug :put_view, Cog.V1.GroupView

  def index(conn, %{"id" => id}) do
    case Groups.by_id(id) do
      {:ok, group} ->
        conn
        |> put_status(:ok)
        |> render("show.json", group: group)
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{errors: "Group not found"})
      {:error, :bad_id} ->
        conn
        |> put_status(:bad_request)
        |> json(%{errors: "Bad ID format"})
    end
  end

  def manage_group_users(conn, %{"users" => user_spec}=params) do
    result = params
    |> Map.put("members", %{"users" => user_spec})
    |> Map.delete("users")
    |> Groups.manage_membership

    case result do
      {:ok, group} ->
        conn
        |> render("show.json", group: group)
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{errors: "Group not found"})
      {:error, :bad_id} ->
        conn
        |> put_status(:bad_request)
        |> json(%{errors: "Bad ID format"})
      {:error, {:not_found, {key, names}}} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{"errors" => %{"not_found" => %{key => names}}})
      {:error, :cannot_remove_admin_user} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: "The admin user cannot be removed from the cog-admin group"})
    end
  end


end

