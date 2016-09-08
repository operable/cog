defmodule Cog do
  require Logger
  use Application

  import Supervisor.Spec, warn: false

  def start(_type, _args) do
    children = [worker(Cog.BusDriver, [], shutdown: 1000),
                worker(Cog.Repo, []),
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
        :ok = verify_schema_migration!

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

        {:ok, top_sup}
      error ->
        error
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
