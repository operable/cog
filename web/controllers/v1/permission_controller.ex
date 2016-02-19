defmodule Cog.V1.PermissionController do
  use Cog.Web, :controller

  alias Cog.Models.EctoJson
  alias Cog.Models.Permission
  alias Cog.Models.Permission.Namespace
  alias Cog.Queries

  plug :scrub_params, "permission" when action in [:create, :update]

  plug Cog.Plug.Authentication
  plug Cog.Plug.Authorization, permission: "#{Cog.embedded_bundle}:manage_permissions"

  @site "site"

  def index(conn, params) do
    permissions = filtered_permissions_query(params)
    |> Repo.all
    |> Repo.preload(:namespace)

    json(conn, EctoJson.render(permissions, envelope: :permissions, policy: :summary))
  end

  @doc """
  Creates a permission in the site namespace.

  Given a permission 'name' (using the 'site' namespace that
  already exists in the system), a new permission will be created.
  """
  def create(conn, %{"permission" => params}) do
    namespace = Repo.get_by(Namespace, name: @site)
    permission = Permission.build_new(namespace, params)
    case Repo.insert(permission) do
      {:ok, permission} ->
        permission = Repo.preload(permission, :namespace)

        conn
        |> put_status(:created)
        |> put_resp_header("location", permission_path(conn, :show, permission))
        |> json(EctoJson.render(permission, envelope: :permission, policy: :detail))
     {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(Cog.ChangesetView, "error.json", changeset: changeset)
    end
  end

  @doc """
  Shows details of a specific permission
  """
  def show(conn, %{"id" => id}) do
    permission = Permission
    |> Repo.get!(id)
    |> Repo.preload(:namespace)

    json(conn, EctoJson.render(permission, envelope: :permission, policy: :detail))
  end

  @doc """
  Updates only 'site' namespaced permissions
  """
  def update(conn, %{"id" => id, "permission" => params}) do
    permission = Permission
    |> Repo.get!(id)
    |> Repo.preload(:namespace)

    case permission.namespace.name do
      @site ->
        changeset = Permission.changeset(permission, params)
        update_permission(conn, changeset)
      _ ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Modifying permissions outside of the #{@site} namespace is forbidden."})
    end
  end

  @doc """
  Deletes permissions from only the 'site' namespace
  """
  def delete(conn, %{"id" => id}) do
    permission = Permission
    |> Repo.get!(id)
    |> Repo.preload(:namespace)

    case permission.namespace.name do
      @site ->
        permission = Repo.get!(Permission, id)
        Repo.delete!(permission)
        send_resp(conn, :no_content, "")
      _ ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Deleting permissions outside of the #{@site} namespace is forbidden."})
    end
  end

  def filtered_permissions_query(%{"user_id" => user}),
    do: Queries.Permission.directly_granted_to_user(user)
  def filtered_permissions_query(%{"group_id" => group}),
    do: Queries.Permission.directly_granted_to_group(group)
  def filtered_permissions_query(%{"role_id" => role}),
    do: Queries.Permission.directly_granted_to_role(role)
  def filtered_permissions_query(_params),
    do: Permission

  defp update_permission(conn, changeset) do
    case Repo.update(changeset) do
      {:ok, permission} ->
        json(conn, EctoJson.render(permission, envelope: :permission, policy: :detail))
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(Cog.ChangesetView, "error.json", changeset: changeset)
    end
  end

end
