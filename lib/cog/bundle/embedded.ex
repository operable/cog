defmodule Cog.Bundle.Embedded do
  @moduledoc """
  Supervises all commands from the embedded command bundle
  """

  use Supervisor
  use Adz

  alias Carrier.CredentialManager
  alias Carrier.Credentials
  alias Cog.Models.Bundle
  alias Cog.Repo
  alias Spanner.Bundle.Config
  alias Spanner.GenCommand

  @embedded_bundle_root "lib/cog"

  @doc """
  Start up a supervisor for the embedded `#{Cog.embedded_bundle}` bundle.

  If the bundle is not present in the database (because the system has
  not been bootstrapped yet, for instance), no supervisor will be
  started.
  """
  def start_link(),
    do: Supervisor.start_link(__MODULE__, [], name: __MODULE__)

  def init([]) do
    announce_embedded_bundle
    Logger.info("Embedded bundle announced; starting bundle supervision tree")

    %Bundle{} = bundle = Repo.get_by!(Bundle, name: Cog.embedded_bundle)
    Logger.info("Loading embedded `#{Cog.embedded_bundle}` bundle")
    bundle_name = bundle.config_file["bundle"]["name"]
    commands = bundle.config_file["commands"]
    children = for command <- commands do
      module_name = command["module"]
      cmd_name = command["name"]
      module = Module.concat([module_name])
      worker(GenCommand, [bundle_name, cmd_name, module, []], id: module)
    end
    supervise(children, strategy: :rest_for_one, max_restarts: 5, max_seconds: 60)
  end

  # Makes a blocking call to the `Cog.Relay.Relays` server to
  # announce the bot as a host for the embedded command bundle. While
  # "real" Relays use the MQTT bus to make such announcements, we're
  # using a special Erlang message call, set aside solely for this use
  # case, so that we can block until the bundle is installed in the
  # database. At that point, we can proceed to fire up the various
  # command processes of the bundle
  defp announce_embedded_bundle do
    Logger.info("Announcing embedded bundle")
    {:ok, %Credentials{id: relay_id}} = CredentialManager.get()
    bundle = embedded_bundle
    message = %{"data" => %{"announce" => %{"relay" => relay_id,
                                            "online" => true,
                                            "snapshot" => true,
                                            "bundles" => [bundle]}}}
    :ok = GenServer.call(Cog.Relay.Relays, {:announce_embedded_relay, message})
  end

  # These permissions aren't yet being used by any embedded commands,
  # so we need to add them manually.
  @remaining_embedded_bundle_permissions ["#{Cog.embedded_bundle}:manage_permissions"]

  defp embedded_bundle do
    Cog.embedded_bundle
    |> Config.gen_config(cog_modules, @embedded_bundle_root)
    |> update_in(["permissions"],
                 &(&1 ++ @remaining_embedded_bundle_permissions))
  end

  defp cog_modules,
    do: Keyword.fetch!(cog_app, :modules)

  defp cog_app do
    app_file = Application.app_dir(:cog, "ebin/cog.app")
    {:ok, [{:application, :cog, app}]} = :file.consult(app_file)
    app
  end
end
