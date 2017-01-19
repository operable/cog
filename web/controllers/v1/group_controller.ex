defmodule Cog.V1.GroupController do
  use Cog.Web, :controller

  alias Cog.Repository.Groups

  plug Cog.Plug.Authentication
  plug Cog.Plug.Authorization, permission: "#{Cog.Util.Misc.embedded_bundle}:manage_groups"

  plug :scrub_params, "group" when action in [:create, :update]

  def index(conn, _params) do
    groups = Groups.all
    render(conn, "index.json", groups: groups)
  end

  def create(conn, %{"group" => group_params}) do
    case Groups.new(group_params) do
      {:ok, group} ->
        new_group = Repo.preload(group, [:direct_user_members, :direct_group_members, :roles])
        conn
        |> put_status(:created)
        |> put_resp_header("location", group_path(conn, :show, group))
        |> render("show.json", group: new_group)
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(Cog.ChangesetView, "error.json", changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
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
    params = Map.put(params, "group", %{"users" => user_spec})
    update(conn, params)
  end

  def update(conn, %{"id" => id, "group" => group_params}) do
    results = with {:ok, group} <- Groups.by_id(id) do
      Groups.update(group, group_params)
    end

    case results do
      {:ok, updated} ->
        render(conn, "show.json", group: updated)
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
      {:error, {:permanent_role_grant, role_name, group_name}} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Cannot remove '#{role_name}' role from '#{group_name}' group"})
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(Cog.ChangesetView, "error.json", changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    results = with {:ok, group} <- Groups.by_id(id) do
      Groups.delete(group)
    end

    case results do
      {:ok, _} ->
        send_resp(conn, :no_content, "")
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

end
