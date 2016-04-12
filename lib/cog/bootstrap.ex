defmodule Cog.Bootstrap do
  @moduledoc """
  Support functions for bootstrapping a Cog chatbot system.
  """

  alias Cog.Models.Permission.Namespace
  alias Cog.Models.User
  alias Cog.Models.Group
  alias Cog.Models.Role
  alias Cog.Repo

  @command_option_types ["int", "float", "string", "bool"]
  @default_admin_params %{
    "username" => "admin",
    "first_name" => "Cog",
    "last_name" => "Administrator",
    "email_address" => "cog@localhost"
  }

  @doc """
  Returns true if the system has been bootstrapped,
  false if not.
  """
  def is_bootstrapped? do
    case Repo.get_by(Group, name: Cog.admin_group) do
      %Group{} -> true
      nil -> false
    end
  end

  @doc """
  Create a user with permissions in the embedded namespace then
  returns the admin user
  """
  def bootstrap,
  do: bootstrap(@default_admin_params)

  def bootstrap(params) when params == %{},
  do: bootstrap(@default_admin_params)

  def bootstrap(params) do
    Repo.transaction(fn() ->
      user = create_admin(params)
      role = create_by_name(Role, Cog.admin_role)
      group = create_by_name(Group, Cog.admin_group)

      grant_embedded_permissions_to(role)
      grant_role_to_group(group, role)
      add_user_to_group(user, group)

      create_by_name(Namespace, Cog.site_namespace)

      user
    end)
  end

  # Create a bootstrap admin user from the given parameter map. If
  # the password is empty, generate a random one. Returns the username
  # and password in the response.
  defp create_admin(params) do
    params = Map.put_new_lazy(params, "password", &generate_safe_password/0)
    User.changeset(%User{}, params) |> Repo.insert!
  end

  defp create_by_name(model, name) do
    model.__struct__
    |> model.changeset(%{name: name})
    |> Repo.insert!
  end

  defp grant_embedded_permissions_to(role) do
    Cog.embedded_bundle
    |> Cog.Queries.Permission.from_bundle_name
    |> Repo.all
    |> Enum.each(&Permittable.grant_to(role, &1))
  end

  defp grant_role_to_group(group, role) do
    Permittable.grant_to(group, role)
  end

  defp add_user_to_group(user, group) do
    Groupable.add_to(user, group)
  end

  defp generate_safe_password do
    # Strip ; and # from passwords so that ConfigParse_Ex doesn't
    # choke on them.
    String.replace(Cog.Passwords.generate_password(32), ~r/[;#]/, "")
  end
end
