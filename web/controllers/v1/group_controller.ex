defmodule Cog.V1.GroupController do
  use Cog.Web, :controller

  alias Cog.Models.EctoJson
  alias Cog.Models.Group

  plug Cog.Plug.Authentication
  plug Cog.Plug.Authorization, permission: "#{Cog.embedded_bundle}:manage_groups"

  plug :scrub_params, "group" when action in [:create, :update]

  def index(conn, _params) do
    groups = Repo.all(Group)
    json(conn, EctoJson.render(groups, envelope: :groups, policy: :summary))
  end

  def create(conn, %{"group" => group_params}) do
    changeset = Group.changeset(%Group{}, group_params)

    case Repo.insert(changeset) do
      {:ok, group} ->
        conn
        |> put_status(:created)
        |> put_resp_header("location", group_path(conn, :show, group))
        |> json(EctoJson.render(group, envelope: :group, policy: :detail))
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(Cog.ChangesetView, "error.json", changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    group = Repo.get!(Group, id)
    json(conn, EctoJson.render(group, envelope: :group, policy: :detail))
  end

  def update(conn, %{"id" => id, "group" => group_params}) do
    group = Repo.get!(Group, id)
    changeset = Group.changeset(group, group_params)

    case Repo.update(changeset) do
      {:ok, group} ->
        json(conn, EctoJson.render(group, envelope: :group, policy: :detail))
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
