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
    permission
  end

  # Expects to be called after the `Cog.Plug.Authentication` plug
  def call(conn, permission_name) do
    authenticated_user = get_user(conn)
    permission = name_to_permission(permission_name)
    case User.has_permission(authenticated_user, permission) do
      true ->
        conn
      false ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Not authorized."})
        |> halt
    end
  end

  defp name_to_permission(name) do
    name
    |> Cog.Queries.Permission.from_full_name
    |> Repo.one!
  end
end
