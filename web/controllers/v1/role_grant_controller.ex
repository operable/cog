defmodule Cog.V1.RoleGrantController do
  use Cog.Web, :controller

  alias Cog.Models.EctoJson
  alias Cog.Models.User
  alias Cog.Models.Role
  alias Cog.Models.Group

  plug Cog.Plug.Authentication

  plug Cog.Plug.Authorization, [permission: "#{Cog.embedded_bundle}:manage_users"] when action == :manage_user_roles
  plug Cog.Plug.Authorization, [permission: "#{Cog.embedded_bundle}:manage_groups"] when action == :manage_group_roles

  def manage_user_roles(conn, params),
    do: manage_roles(conn, User, params)

  def manage_group_roles(conn, params),
    do: manage_roles(conn, Group, params)

  # Grant or revoke an arbitrary number of roles (specified as
  # names) from the identified entity (i.e., the thing of
  # type `type` the given `id`). Returns a detail list of all
  # *directly*-granted roles the thing has has following the
  # grant / revoke actions.
  defp manage_roles(conn, type, %{"id" => id, "roles" => role_spec}) do
    result = Repo.transaction(fn() ->
      permittable = Repo.get!(type, id)

      roles_to_grant  = lookup_or_fail(role_spec, "grant")
      roles_to_revoke = lookup_or_fail(role_spec, "revoke")

      permittable
      |> grant(roles_to_grant)
      |> revoke(roles_to_revoke)
      |> Repo.preload(:roles)
    end)

    case result do
      {:ok, permittable} ->
        conn
        |> json(EctoJson.render(permittable.roles, envelope: :roles, policy: :detail))
      {:error, {:not_found, {"roles", names}}} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{"error" => %{"not_found" => %{"roles" => names}}})
    end
  end

  defp lookup_or_fail(role_spec, operation) do
    names = get_in(role_spec, [operation]) || []
    case lookup_all(names) do
      {:ok, roles} -> roles
      {:error, reason} ->
        Repo.rollback(reason)
    end
  end

  defp lookup_all([]), do: {:ok, []} # Don't bother with a DB lookup
  defp lookup_all(names) do
    results = Repo.all(from r in Role, where: r.name in ^names)

    # make sure we got a result for each name given
    case length(results) == length(names) do
      true ->
        # Each name corresponds to an entity in the database
        {:ok, results}
      false ->
        # We got at least one name that doesn't map to any existing
        # role. Find out what's missing and report back
        retrieved_names = Enum.map(results, &Map.get(&1, :name))
        bad_names = names -- retrieved_names
        {:error, {:not_found, {"roles", bad_names}}}
    end
  end

  defp grant(user, permissions) do
    Enum.each(permissions, &Permittable.grant_to(user, &1))
    user
  end

  defp revoke(user, permissions) do
    Enum.each(permissions, &Permittable.revoke_from(user, &1))
    user
  end

end
