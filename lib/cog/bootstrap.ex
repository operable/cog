defmodule Cog.Bootstrap do
  @moduledoc """
  Support functions for bootstrapping a Cog system.
  """

  require Logger

  alias Cog.Models.Group
  alias Cog.Models.Role
  alias Cog.Models.User
  alias Cog.Repo
  alias Cog.Repository.Relays, as: RelaysRepo
  alias Cog.Repository.RelayGroups, as: RelayGroupsRepo

  @default_admin_params %{
    "username"      => "admin",
    "first_name"    => "Cog",
    "last_name"     => "Administrator",
    "email_address" => "cog@localhost"
  }

  @default_relay_params %{
    "name"        => "default",
    "description" => "Default relay",
    "enabled"     => true
  }

  @default_relay_group_params %{
    "name"        => "default",
    "description" => "Default relay group"
  }

  @doc """
  Returns `true` if the system has been bootstrapped, `false` if not.
  """
  def is_bootstrapped? do
    case Repo.get_by(Group, name: Cog.Util.Misc.admin_group) do
      %Group{} -> true
      nil -> false
    end
  end

  # TODO: Consider removing this 0-arity function in favor of
  # `bootstrap(:defaults)`, discussed below. It appears to only be
  # used in tests.
  @doc """
  Create a user with permissions in the embedded namespace then
  returns the admin user
  """
  def bootstrap,
    do: bootstrap(@default_admin_params)

  # TODO: The bootstrap controller uses an empty map when the user
  # doesn't supply any parameters. We should probably change that to
  # something like `:defaults` instead of an empty map.
  def bootstrap(params) when params == %{},
    do: bootstrap(@default_admin_params)
  def bootstrap(params) do
    Repo.transaction(fn() ->
      user  = create_admin(params)
      role  = create_by_name(Role, Cog.Util.Misc.admin_role)
      group = create_by_name(Group, Cog.Util.Misc.admin_group)

      grant_embedded_permissions_to(role)
      Permittable.grant_to(group, role)
      Groupable.add_to(user, group)

      user
    end)
  end

  # Bootstraps using environment variables if they are present.
  @doc """
  Create an administrative user using values from the environment, if present.
  If any of the following variables are not set, the bootstrap will not be
  performed. Required variables:

  COG_BOOTSTRAP_USERNAME
  COG_BOOTSTRAP_PASSWORD
  COG_BOOTSTRAP_EMAIL_ADDRESS
  COG_BOOTSTRAP_FIRST_NAME
  COG_BOOTSTRAP_LAST_NAME

  Additionally, if the user bootstrap completes successfully and the RELAY_ID
  and RELAY_COG_TOKEN variables are set, a relay will be created using the
  variables and assigned to a default relay group, which will also be created.
  If the relevant variables are not present, this step will be skipped.

  If any creation attempt fails, the entire bootstrap process will be rolled
  back.
  """
  def maybe_bootstrap do
    unless is_bootstrapped? do
      result = Repo.transaction fn ->
        case bootstrap_from_env do
          {:ok, user} ->
            relay_from_env(System.get_env)
            user
          _ ->
            :not_bootstrapped
        end
      end

      # Associating a chat handle currently takes place within its own
      # transaction. Here, it's OK if the operation fails. For
      # expediency, we pull this operation out of the above
      # transaction.
      case result do
        {:ok, %User{}=user} ->
          maybe_bootstrap_chat_handle_from_env(user, System.get_env("COG_BOOTSTRAP_CHAT_HANDLE"))
        _ ->
          :ok
      end
    end
  end

  ########################################################################

  defp bootstrap_from_env do
    fields = ~w(username password email_address first_name last_name)
    vars =
      Enum.map(fields, fn(field) -> { field, System.get_env(bootstrap_var_for(field)) } end)
      |> Enum.group_by(fn({_k,v}) -> if (v != nil), do: :found, else: :not_found end)

    if vars[:found] do
      case vars[:not_found] do
        # All variables accounted for, proceed with bootstrap
        nil ->
          Logger.info("Bootstrapping Cog from environment variables.")
          bootstrap(Enum.into(vars[:found], %{}))

        # We found some, but not all, of the required variables. Since it seems
        # like the user was attempting to bootstrap via environment we will
        # warn about the missing variables.
        missing ->
          Enum.each(missing, fn({k,_v}) -> Logger.info("Skipping bootstrap: Missing value for #{bootstrap_var_for(k)}.") end)
          false
      end
    end
  end

  defp bootstrap_var_for(key) do
    "COG_BOOTSTRAP_" <> String.upcase(key)
  end

  defp relay_from_env(%{"RELAY_ID" => relay_id,
                        "RELAY_COG_TOKEN" => relay_token}) do
    Logger.info("Configuring default relay from environment variables.")
    relay_params = %{ "id" => relay_id, "token" => relay_token }
    |> Map.merge(@default_relay_params)

    :ok =
      with {:ok, relay} <- RelaysRepo.new(relay_params),
           {:ok, relay_group} <- RelayGroupsRepo.new(@default_relay_group_params),
      do: Groupable.add_to(relay, relay_group)
  end
  defp relay_from_env(_) do
    :not_configured
  end

  defp maybe_bootstrap_chat_handle_from_env(_user, nil),
    do: Logger.info("No chat handle specified for bootstrap user; skipping")
  defp maybe_bootstrap_chat_handle_from_env(user, handle) do
    {:ok, provider_name} = Cog.Util.Misc.chat_adapter_module()
    case Cog.Repository.ChatHandles.set_handle(user, provider_name, handle) do
      {:ok, _} ->
        Logger.info("Associated bootstrap user with chat handle '#{handle}'")
        :ok
      {:error, reason} ->
        Logger.error("Could not associate bootstrap user with chat handle '#{handle}': #{reason}")
    end
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
    Cog.Util.Misc.embedded_bundle
    |> Cog.Queries.Permission.from_bundle_name
    |> Repo.all
    |> Enum.each(&Permittable.grant_to(role, &1))
  end

  # TODO: We should just move this into Cog.Passwords and make it the
  # default.
  defp generate_safe_password do
    # Strip ; and # from passwords so that ConfigParse_Ex doesn't
    # choke on them.
    String.replace(Cog.Passwords.generate_password(32), ~r/[;#]/, "")
  end
end
