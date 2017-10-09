defmodule Cog do
  require Logger
  use Application

  import Supervisor.Spec, warn: false

  def restart() do
    Logger.debug("Stopping Cog...")
    :ok = Application.stop(:cog)
    Logger.debug("Cog stopped. Restarting...")
    {:ok, _}  =  Application.ensure_all_started(:cog)
    Logger.debug("Cog restarted.")
  end

  def start(_type, _args) do
    Application.put_env(:cog, :message_queue_password, gen_password(64))

    maybe_display_unenforcing_warning()
    children = [worker(Cog.BusDriver, [], shutdown: 1000),
                supervisor(Carrier.Messaging.ConnectionSup, []),
                supervisor(Cog.DBSup, []),
                supervisor(Cog.CoreSup, [])]

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
        :ok = verify_schema_migration!()

        # Bootstrap the administrative user and an optional relay if the
        # necessary environment variables are set and Cog is not already
        # bootstrapped.
        Cog.Bootstrap.maybe_bootstrap

        # In the absence of persistent tracking of the previous
        # vs. current Cog version running, we'll just ensure at
        # startup that the common templates in the database mirror the
        # template files currently in Cog's priv directory. If we did
        # track previous vs. current Cog version, then we could just
        # do this when Cog was upgraded.
        Logger.info("Ensuring common templates are up-to-date")
        Cog.Repository.Templates.refresh_common_templates!

        # Disable bundles that have an unsupported config version
        # If Cog is upgraded incompatible bundles that were installed
        # previously will be disabled and a warning message displayed
        # to the user. Nothing will happen if there are no enabled
        # incompatible bundle versions.
        Cog.Repository.Bundles.disable_incompatible_bundles()
        |> Enum.map(&Logger.warn("""
        Detected unsupported bundle config version '#{&1.config_file["cog_bundle_version"]}'. \
        Disabling incompatible bundle '#{&1.bundle.name}', version '#{&1.version}'. \
        Update your bundle config to the newest version, '#{Spanner.Config.current_config_version}' and reinstall.\
        """))

        # Send a start event to the Operable telemetry service
        Cog.Telemetry.send_event(:start)

        {:ok, top_sup}
      error ->
        error
    end
  end

  defp verify_schema_migration! do
    case migration_status() do
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

  defp maybe_display_unenforcing_warning() do
    case Application.get_env(:cog, :access_rules) do
      :unenforcing ->
        Logger.warn("Access rule enforcement has been GLOBALLY disabled. ALL command invocations will be permitted.")
      _ ->
        :ok
    end
  end

  # Generate a random string `length` characters long
  defp gen_password(length) do
    :crypto.strong_rand_bytes(length)
    |> Base.encode64
    |> binary_part(0, length)
  end

end
