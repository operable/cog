defmodule Cog do
  require Logger
  use Application

  import Supervisor.Spec, warn: false

  def start(_type, _args) do
    adapter_supervisor = get_adapter_supervisor!()
    children = [worker(Cog.Repo, []),
                worker(Cog.BusDriver, [], shutdown: 10000),
                worker(Cog.TokenReaper, []),
                worker(Carrier.CredentialManager, []),
                supervisor(Cog.Relay.RelaySup, []),

                # TODO: Need to put this and commandsup under a supervisor
                supervisor(Cog.Command.Service.Supervisor, []),

                supervisor(Cog.Command.CommandSup, []),
                supervisor(adapter_supervisor, []),
                supervisor(Cog.Endpoint, []),
                supervisor(Cog.TriggerEndpoint, []),
                supervisor(Cog.Adapters.Http.Supervisor,[])]

    opts = [strategy: :one_for_one, name: Cog.Supervisor]
    case Supervisor.start_link(children, opts) do
      {:ok, top_sup} ->
        # Verify the latest schema migration after starting the database worker
        #
        # NOTE: This _may_ cause issues in the future, since we
        # currently announce and install the embedded bundle during
        # startup (i.e., before doing the schema migration check). If
        # at some point we were to automatically upgrade the embedded
        # bundle in such a way that required a database migration
        # beforehand, the resulting error might be confusing.
        #
        # Consider doing this in a process that runs after the Repo
        # comes up, but before anything else is done
        :ok = verify_schema_migration!
        {:ok, top_sup}
      error ->
        error
    end
  end

  @doc "The name of the embedded command bundle."
  def embedded_bundle, do: "operable"

  @doc "The name of the site namespace."
  def site_namespace, do: "site"

  @doc "The name of the admin role."
  def admin_role, do: "cog-admin"

  @doc "The name of the admin group."
  def admin_group, do: "cog-admin"

  ########################################################################
  # Adapter Resolution Functions

  @doc """
  Returns the currently configured chat adapter module, if found.
  """
  @spec chat_adapter_module :: {:ok, module} | {:error, {:bad_adapter, configured_name :: String.t}}
  def chat_adapter_module,
    do: chat_adapter_module(Application.get_env(:cog, :adapter))

  @doc """
  For a given _chat_ adapter name return the implementing module, if
  it exists.
  """
  @spec chat_adapter_module(String.t) :: {:ok, module} | {:error, {:bad_adapter, String.t}}
  def chat_adapter_module(name),
    do: adapter_module(name, chat_adapters)

  @doc """
  Same as `chat_adapter_module/1` but for _any_ adapter, chat or
  otherwise.
  """
  @spec chat_adapter_module(String.t) :: {:ok, module} | {:error, {:bad_adapter, String.t}}
  def adapter_module(name),
    do: adapter_module(name, all_adapters)

  # Note: chat_adapters/0, non_chat_adapters/0, and all_adapters/0 are
  # only really public to facilitate testing; once we have a more
  # dynamic scheme for managing adapters, they won't be necessary.

  # TODO: the "null" and "test" adapters need to be brought in only in
  # non-prod environments
  def chat_adapters do
    %{"slack"   => Cog.Adapters.Slack,
      "hipchat" => Cog.Adapters.HipChat,
      "irc"     => Cog.Adapters.IRC,
      "null"    => Cog.Adapters.Null,
      "test"    => Cog.Adapters.Test}
  end

  def non_chat_adapters,
    do: %{"http" => Cog.Adapters.Http}

  def all_adapters,
    do: Map.merge(chat_adapters, non_chat_adapters)

  ########################################################################

  defp adapter_module(name, source) do
    case Map.fetch(source, name) do
      {:ok, module} ->
        {:ok, module}
      :error ->
        {:error, {:bad_adapter, name}}
    end
  end

  defp get_adapter_supervisor!() do
    case chat_adapter_module do
      {:ok, adapter} ->
        Logger.info "Using #{inspect adapter} chat adapter"
        supervisor = Module.concat(adapter, "Supervisor")

        case Code.ensure_loaded(supervisor) do
          {:module, ^supervisor} ->
            supervisor
          {:error, _} ->
            raise RuntimeError, "#{inspect(supervisor)} was not found. Please define a supervisor for the #{inspect(adapter)} adapter"
        end
      {:error, {:bad_adapter, bad_adapter}} ->
        raise RuntimeError, "The adapter is set to #{inspect(bad_adapter)}, but I don't know what that is. Try one of the following values instead: #{Enum.map_join(Map.keys(chat_adapters), ", ", &inspect/1)}"
    end
  end

  defp verify_schema_migration! do
    case migration_status do
      :ok ->
        Logger.info("Database schema is up-to-date")
      {:error, have, want} ->
        case Mix.env do
          :dev ->
            Logger.warn("The database schema is at version #{have}, but the latest schema is #{want}. Allowing to continue in the development environment.")
          _ ->
            raise RuntimeError, "The database schema is at version #{have}, but the latest schema is #{want}. Please perform a migration and restart Cog."
        end
    end
  end

  # Determine if the database has had all migrations applied. If not,
  # return the currently applied version and the latest unapplied version
  @spec migration_status :: :ok | {:error, have, want} when have: pos_integer,
                                                            want: pos_integer
  defp migration_status do
    # Migration file names are like `20150923192906_create_users.exs`;
    # take the leading date portion of the most recent migration as
    # the version
    latest_migration = Path.join([:code.priv_dir(:cog), "repo", "migrations"])
    |> File.ls!
    |> Enum.max
    |> String.split("_", parts: 2)
    |> List.first
    |> String.to_integer

    # Perform similar logic to see what's latest in the database
    latest_applied_migration = Enum.max(Ecto.Migration.SchemaMigration.migrated_versions(Cog.Repo, "public"))

    if latest_applied_migration == latest_migration do
      :ok
    else
      {:error, latest_applied_migration, latest_migration}
    end
  end

end
