defmodule Cog.Plug.Authorization do
  @behaviour Plug

  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]
  import Cog.Plug.Util, only: [get_user: 1]

  alias Cog.Models.User
  alias Cog.Models.Permission
  alias Cog.Repo

  @typedoc """
  Namespaced permission name a user must have in order to be authorized
  """
  @type permission_opt :: {:permission, String.t}

  @typedoc """
  Boolean flag indicating whether or not 'self updates' are authorized
  'Self update' is defined as then invocation of `:show` or `:update` action
  when the path parameter `id` matches the currently authenticated user.
  """
  @type self_updates_opt :: {:allow_self_updates, bool}

  @type auth_options :: [permission_opt | self_updates_opt]

  @doc """
  Options:
    `:permission` - Fully namespaced permission name required for authorization
    `:allow_self_updates` - Permit user to edit their own data. Defaults to false
                            if unset.

  Example:

  ```
  plug Cog.Plug.Authorization, [permission: "operable:manage_users",
                                allow_self_updates: true]
  ```
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
      (conn.assigns.user.id == conn.params["id"] or
      conn.params["id"] == "me")
  end

end
