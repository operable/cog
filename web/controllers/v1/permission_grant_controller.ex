defmodule Cog.V1.PermissionGrantController do
  use Cog.Web, :controller

  alias Cog.Models.EctoJson
  alias Cog.Models.User
  alias Cog.Models.Permission
  alias Cog.Models.Role
  alias Cog.Models.Group

  plug Cog.Plug.Authentication

  plug Cog.Plug.Authorization, [permission: "#{Cog.embedded_bundle}:manage_users"] when action == :manage_user_permissions
  plug Cog.Plug.Authorization, [permission: "#{Cog.embedded_bundle}:manage_roles"] when action == :manage_role_permissions
  plug Cog.Plug.Authorization, [permission: "#{Cog.embedded_bundle}:manage_groups"] when action == :manage_group_permissions

  def manage_role_permissions(conn, params),
    do: manage_permissions(conn, Role, params)

  def manage_user_permissions(conn, params),
    do: manage_permissions(conn, User, params)

  def manage_group_permissions(conn, params),
    do: manage_permissions(conn, Group, params)


  # Grant or revoke an arbitrary number of permissions (specified as
  # namespaced names) from the identified entity (i.e., the thing of
  # type `type` the given `id`). Returns a detail list of all
  # *directly*-granted permissions the thing has has following the
  # grant / revoke actions.
  defp manage_permissions(conn, type, %{"id" => id, "permissions" => permission_spec}) do
    result = Repo.transaction(fn() ->
      permittable = Repo.get!(type, id)

      permissions_to_grant  = lookup_or_fail(permission_spec, "grant")
      permissions_to_revoke = lookup_or_fail(permission_spec,  "revoke")

      permittable
      |> grant(permissions_to_grant)
      |> revoke(permissions_to_revoke)
      |> Repo.preload(permissions: :namespace)
    end)

    case result do
      {:ok, permittable} ->
        conn
        |> json(EctoJson.render(permittable.permissions, envelope: :permissions, policy: :detail))
      {:error, {:not_found, {"permissions", names}}} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{"error" => %{"not_found" => %{"permissions" => names}}})
    end
  end

  defp lookup_or_fail(permission_spec, operation) do
    names = get_in(permission_spec, [operation]) || []
    case lookup_all("permissions", names) do
      {:ok, structs} -> structs
      {:error, reason} ->
        Repo.rollback(reason)
    end
  end

  defp lookup_all(_, []), do: {:ok, []} # Don't bother with a DB lookup
  defp lookup_all("permissions", names) do

    # Resolve each namespaced name to a %Permission{}. Return a list
    # of tuples `{name, lookup_result}` for future filtering
    results = Enum.map(names, fn(name) ->
      permission = Cog.Queries.Permission.from_full_name(name) |> Repo.one
      {name, permission}
    end)

    # Figure out which of those permissions actually exist in the
    # system. If any don't (signified by `nil`), we'll use this for an
    # error message.
    {missing, found} = Enum.partition(results,
      fn({_,nil}) -> true
        ({_,%Permission{}}) -> false
      end)

    case missing do
      [] ->
        # They're all real permissions! Get rid of the wrapping tuple;
        # just give back the permissions
        unwrapped = Enum.map(found, fn({_,p}) -> p end)
        {:ok, unwrapped}
      missing ->
        # Oops, you gave us permission names that don't actually
        # exist. Return the names in an error tuple
        names = Enum.map(missing, fn({n,_}) -> n end)
        {:error, {:not_found, {"permissions", names}}}
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
