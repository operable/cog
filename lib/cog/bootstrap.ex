defmodule Cog.Bootstrap do
  @moduledoc """
  Support functions for bootstrapping a Cog chatbot system.
  """

  alias Cog.Models.Permission.Namespace
  alias Cog.Models.User
  alias Cog.Repo

  @admin_name "admin"

  @site_namespace "site"
  @command_option_types ["int", "float", "string", "bool"]

  @doc """
  Returns true if the system has been bootstrapped,
  false if not.
  """
  def is_bootstrapped? do
    case Repo.get_by(User, username: @admin_name) do
      %User{} -> true
      nil -> false
    end
  end

  @doc """
  Create a user with permissions in the embedded namespace then
  returns the admin user
  """
  def bootstrap do
    {:ok, user} = Repo.transaction(fn() ->
      user = create_admin
      grant_embedded_permissions_to(user)
      create_namespace(@site_namespace)
      user
    end)

    {:ok, user}
  end

  # TODO: require either username or email (or both), but if one is
  #       missing, that's  OK.
  # TODO: Make first/last name optional?

  # Create a bootstrap admin user. The username will always be
  # `@admin_name`, and the password will be randomly-generated, which
  # will be available in the `password` field of the returned
  # `Cog.Models.User` struct.
  defp create_admin do
    # Horrible quick n' dirty hack to strip
    # ; and # from passwords so ConfigParse_Ex doesn't
    # choke on them.
    password = String.replace(Cog.Passwords.generate_password(32), ~r/[;#]/, "")

    params = %{
      username: @admin_name,
      first_name: "Cog",
      last_name: "Administrator",
      password: password,
      email_address: "cog@localhost"}

    User.changeset(%User{}, params) |> Repo.insert!
  end

  defp grant_embedded_permissions_to(user) do
    Cog.embedded_bundle
    |> Cog.Queries.Permission.from_bundle_name
    |> Repo.all
    |> Enum.each(&Permittable.grant_to(user, &1))
  end

  defp create_namespace(name) do
    %Namespace{}
    |> Namespace.changeset(%{name: name})
    |> Repo.insert!
  end

end
