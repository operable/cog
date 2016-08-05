defmodule Cog.Bundle.Embedded do
  @moduledoc """
  Supervises all commands from the embedded command bundle
  """

  use Supervisor
  use Adz

  alias Cog.Bundle.Config
  alias Cog.Repository

  @doc """
  Start up a supervisor for the embedded `#{Cog.embedded_bundle}` bundle.

  If the bundle is not present in the database (because the system has
  not been bootstrapped yet, for instance), no supervisor will be
  started.
  """
  def start_link(),
    do: Supervisor.start_link(__MODULE__, [], name: __MODULE__)

  def init([]) do
    # TODO: Should we consider additional ways to make the Cog bot appear as
    # a relay in a special relay group? That might reduce our
    # "special snowflake" code a bit more.
    bundle_version = Repository.Bundles.maybe_upgrade_embedded_bundle!(embedded_bundle)
    :ok = Repository.Bundles.ensure_site_bundle

    announce_embedded_bundle(bundle_version)
    Logger.info("Embedded bundle announced; starting bundle supervision tree")

    Logger.info("Loading embedded `#{Cog.embedded_bundle}` bundle")
    config = bundle_version.config_file
    children = Enum.map(config["commands"], fn({command_name, command}) ->
      name = command_name
      module = Module.concat([command["module"]])
      worker(Cog.Command.GenCommand, [bundle_version.bundle.name, name, module, []], id: module)
    end)
    supervise(children, strategy: :rest_for_one, max_restarts: 5, max_seconds: 60)
  end

  # Makes a blocking call to the `Cog.Relay.Relays` server to
  # announce the bot as a host for the embedded command bundle. While
  # "real" Relays use the MQTT bus to make such announcements, we're
  # using a special Erlang message call, set aside solely for this use
  # case, so that we can block until the bundle is installed in the
  # database. At that point, we can proceed to fire up the various
  # command processes of the bundle
  defp announce_embedded_bundle(bundle_version) do
    Logger.info("Announcing embedded bundle")
    message = %Cog.Messages.Relay.Announcement{relay: Cog.Config.embedded_relay(),
                                               online: true,
                                               snapshot: true,
                                               bundles: [%Cog.Messages.Relay.Bundle{name: bundle_version.bundle.name,
                                                                                    version: bundle_version.version}]}
    :ok = GenServer.call(Cog.Relay.Relays, {:announce_embedded_relay, message}, :infinity)
  end

  defp embedded_bundle do
    version = Application.fetch_env!(:cog, :embedded_bundle_version)
    modules = Application.spec(:cog, :modules)

    Config.gen_config(Cog.embedded_bundle,
                      "Core chat commands for Cog",
                      version,
                      modules,
                      Path.join([:code.priv_dir(:cog), "templates"]))
  end

end
