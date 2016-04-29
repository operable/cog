defmodule Cog.Plug.Authorization do
  @behaviour Plug

  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]
  import Cog.Plug.Util, only: [get_user: 1]

  alias Cog.Models.User
  alias Cog.Models.Permission
  alias Cog.Repo

  @doc """
  Requires a `:permission` option, which should be the namespaced name
  of a permission that a user must have in order to be authorized.
  """
  def init(opts) do
    permission = Keyword.fetch!(opts, :permission)
    unless is_bitstring(permission) do
      raise ":permission key must be a string, but was '#{inspect permission}' instead"
    end
    {_,_} = Permission.split_name(permission) # error if can't be split
    opts
  end

  # Expects to be called after the `Cog.Plug.Authentication` plug
  def call(conn, opts) do
    permission_name = Keyword.fetch!(opts, :permission)
    authenticated_user = get_user(conn)
    permission = name_to_permission(permission_name)
    case User.has_permission(authenticated_user, permission) do
      true ->
        conn
      false ->
        if Keyword.get(opts, :allow_self_updates, false) do
          if self_updating?(conn) do
            conn
          else
            forbid_access(conn)
          end
        else
          forbid_access(conn)
        end
    end
  end

  defp forbid_access(conn) do
    conn
    |> put_status(:forbidden)
    |> json(%{error: "Not authorized."})
    |> halt
  end

  defp name_to_permission(name) do
    name
    |> Cog.Queries.Permission.from_full_name
    |> Repo.one!
  end

  # NOTE: This code assumes the id path parameter is the
  # the user's ID. We should consider making this configurable
  # in the future. For example, this would allow users to update
  # related data with paths such as `/v1/users/:user_id/profiles/:id`.
  defp self_updating?(conn) do
    conn.private.phoenix_action in [:update, :show] and
      conn.assigns.user.id == conn.params["id"] or
      conn.params["id"] == "me"
  end

end
