defmodule Cog.V1.GroupController do
  use Cog.Web, :controller

  alias Cog.Models.Group

  plug Cog.Plug.Authentication
  plug Cog.Plug.Authorization, permission: "#{Cog.embedded_bundle}:manage_groups"

  plug :scrub_params, "group" when action in [:create, :update]

  def index(conn, _params) do
    groups = Repo.all(Group)
    |> Repo.preload([:direct_user_members, :direct_group_members, :roles])
    render(conn, "index.json", groups: groups)
  end

  def create(conn, %{"group" => group_params}) do
    changeset = Group.changeset(%Group{}, group_params)

    case Repo.insert(changeset) do
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
    group = Repo.get!(Group, id)
    |> Repo.preload([:direct_user_members, :direct_group_members, :roles])
    render(conn, "show.json", group: group)
  end

  def update(conn, %{"id" => id, "group" => group_params}) do
    group = Repo.get!(Group, id)
    changeset = Group.changeset(group, group_params)

    case Repo.update(changeset) do
      {:ok, group} ->
        render(conn, "show.json", group: group)
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(Cog.ChangesetView, "error.json", changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    group = Repo.get!(Group, id)
    Repo.delete!(group)
    send_resp(conn, :no_content, "")
  end
end
