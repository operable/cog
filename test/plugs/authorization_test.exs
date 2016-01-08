defmodule Cog.Plug.Authorization.Test do
  use Cog.ModelCase
  use Plug.Test
  alias Cog.Plug.Authorization

  setup do
    user = user("cog")
    granted = permission("#{Cog.embedded_bundle}:manage_users")
    ungranted = permission("#{Cog.embedded_bundle}:manage_groups")
    :ok = Permittable.grant_to(user, granted)
    {:ok, [user: user,
           granted: granted,
           granted_name: "#{Cog.embedded_bundle}:manage_users",
           ungranted: ungranted,
           ungranted_name: "#{Cog.embedded_bundle}:manage_groups"]}
  end

  test "errors if :user assigns is missing", %{granted_name: permission} do
    # Seeing this error in real life means we've miscoded the
    # application and are calling this plug before the Authentication one.
    error = catch_error(conn(:get, "/") |> Authorization.call(permission))
    assert :function_clause = error
  end

  test "init fails without passing a :permission key" do
    error = catch_error(Authorization.init(monkeys: :are_awesome))
    assert %KeyError{} = error
  end

  test "init fails when passing a list of permissions" do
    # permission lookup expects a single string
    error = catch_error(Authorization.init(permission: ["#{Cog.embedded_bundle}:manage_users", "#{Cog.embedded_bundle}:manage_groups"]))
    assert %RuntimeError{} = error
  end

  test "init fails if permission is not namespaced" do
    error = catch_error(Authorization.init(permission: "manage_users"))
    assert {:badmatch, ["manage_users"]} = error
  end

  test "init returns the permission name when it is nominally valid", %{granted_name: name} do
    assert ^name = Authorization.init(permission: name)
  end

  # TODO: we might want to rescue this error, log the problem, and
  # still return 403
  test "plug fails when passing an unrecognized permission" do
    error = catch_error(conn(:get, "/") |> Authorization.call("#{Cog.embedded_bundle}:do_stuff"))
    assert %Ecto.NoResultsError{} = error
  end

  test "plug halts with forbidden if user does not have the required permission",
  %{user: user, ungranted_name: permission} do

    conn = conn(:get, "/") |> assign(:user, user) |> Authorization.call(permission)

    assert conn.halted
    assert conn.status == 403 # forbidden
    assert conn.state == :sent
  end

  test "plug does not halt if user has the required permission",
  %{user: user, granted_name: permission} do

    conn = conn(:get, "/") |> assign(:user, user) |> Authorization.call(permission)

    refute conn.halted
    refute conn.status
  end

end
