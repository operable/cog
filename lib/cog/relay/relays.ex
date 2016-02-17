defmodule Cog.Relay.Relays do

  alias Cog.Relay.Tracker

  defstruct [mq_conn: nil,
             tracker: Tracker.new]

  use Adz
  use GenServer

  alias Carrier.Credentials
  alias Carrier.CredentialManager
  alias Carrier.Messaging
  alias Cog.Models.Bundle
  alias Cog.Repo
  alias Cog.Relay.Util

  @relays_discovery_topic "bot/relays/discover"

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Choses a relay at random that is currently actively running `bundle`.

  Returns the relay's ID, or `nil` if no relay is currently running
  `bundle`.
  """
  @spec pick_one(String.t) :: String.t | nil
  def pick_one(bundle),
    do: GenServer.call(__MODULE__, {:random_active_relay, bundle}, :infinity)

  def drop_bundle(bundle) do
    GenServer.call(__MODULE__, {:drop_bundle, bundle}, :infinity)
  end

  @doc """
  Mark `bundle_name` as having the specified `status`.
  """
  def set_status(bundle_name, status) when status in [:enabled, :disabled],
    do: GenServer.call(__MODULE__, {:set_status, bundle_name, status}, :infinity)

  @doc """
  Returns the current known information for `bundle_name`, or
  an error if the tracker does not know about `bundle_name`.

  Example:

      %{status: :enabled,
        relays: ["44a92066-b1ae-4456-8e6a-4f212ded3180",
                 "85da0992-cfcf-49b5-bc5b-d9bd53fb23cd"]}
  """
  @spec bundle_status(String.t) :: {:ok, map} | {:error, :no_relays_serving_bundle}
  def bundle_status(bundle_name),
    do: GenServer.call(__MODULE__, {:bundle_status, bundle_name}, :infinity)

  def init(_) do
    case Messaging.Connection.connect() do
      {:ok, conn} ->
        Logger.info("Starting")
        Messaging.Connection.subscribe(conn, @relays_discovery_topic)
        # Seed RNG so picking relays at random works
        :random.seed(:os.timestamp())
        {:ok, %__MODULE__{tracker: Tracker.new(), mq_conn: conn}}
      error ->
        Logger.error("Error starting: #{inspect error}")
        error
    end
  end

  def handle_call({:announce_embedded_relay, message}, _from, state) do
    # This function head acts as a private internal API used for
    # registering the bot as a host for the embedded command
    # bundle. (We don't provide a public API function for this message
    # for that reason.)
    #
    # It is a blocking call, because we want to be assured that the
    # bundle is recorded in the database before proceeding.
    #
    # See `Cog.Bundle.Embedded` for more.
    new_state = process_discovery(message, state)
    {:reply, :ok, new_state}
  end
  def handle_call({:random_active_relay, bundle}, _from, state),
    do: {:reply, random_active_relay(state.tracker, bundle), state}
  def handle_call({:drop_bundle, bundle}, _from, state) do
    tracker = Tracker.drop_bundle(state.tracker, bundle)
    {:reply, :ok, %{state | tracker: tracker}}
  end
  def handle_call({:bundle_status, bundle_name} , _from, state) do
    status = Tracker.bundle_status(state.tracker, bundle_name)
    {:reply, status, state}
  end
  def handle_call({:set_status, bundle_name, :disabled}, _from, state) do
    tracker = Tracker.disable_bundle(state.tracker, bundle_name)
    {:reply, :ok, %{state | tracker: tracker}}
  end
  def handle_call({:set_status, bundle_name, :enabled}, _from, state) do
    tracker =  Tracker.enable_bundle(state.tracker, bundle_name)
    {:reply, :ok, %{state | tracker: tracker}}
  end

  def handle_info({:publish, @relays_discovery_topic, message}, state) do
    # Not authenticating messages here, because we don't have the keys
    # to authenticate them at this point!
    case Poison.decode(message) do
      {:ok, json} ->
        state = process_discovery(json, state)
        {:noreply, state}
      _ ->
        {:noreply, state}
    end
  end
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  ########################################################################

  # Common processing of relay announcements, whether they come from a
  # real Relay instance, or from the bot itself, announcing the
  # embedded bundle.
  defp process_discovery(discovery, state) when is_map(state) do
    case Map.fetch!(discovery, "data") do
      %{"intro" => intro} ->
        process_introduction(intro, state)
      %{"announce" => announcement} ->
        process_announcement(announcement, state)
    end
  end

  defp process_introduction(%{"relay" => id,
                              "public_key" => pub_key,
                              "reply_to" => reply_to}, state) do
    case CredentialManager.get(id, by: :id) do
      {:ok, nil} ->
        creds = %Credentials{id: id, public: Base.decode16!(pub_key, case: :lower)}
        CredentialManager.store(creds)
        Logger.info("Stored public key for Relay #{id}")
      {:ok, _} ->
        :ok
    end
    {:ok, my_creds} = CredentialManager.get()
    Messaging.Connection.publish(state.mq_conn, %{intro: %{id: my_creds.id,
                                                           public_key: Base.encode16(my_creds.public, case: :lower),
                                                           role: "bot"}}, routed_by: reply_to)
    state
  end

  defp process_announcement(announcement, %__MODULE__{tracker: tracker}=state) do
    {success_bundles, failed_bundles} = announcement
    |> Map.fetch!("bundles")
    |> Enum.map(&lookup_or_install/1)
    |> Enum.partition(&Util.is_ok?/1)
    |> Util.unwrap_partition_results

    tracker = update_tracker(announcement, tracker, success_bundles)

    case Map.fetch(announcement, "reply_to")  do
      :error ->
        :ok # The embedded bundle has no need for a reply
      {:ok, reply_to} ->
        # If the message has a `reply_to` field, it must also have an
        # `announcement_id` field
        announcement_id = Map.fetch!(announcement, "announcement_id")
        receipt = receipt(announcement_id, failed_bundles)
        Logger.debug("Sending receipt to #{reply_to}: #{inspect receipt}")
        Messaging.Connection.publish(state.mq_conn, receipt, routed_by: reply_to)
    end
    %{state | tracker: tracker}
  end

  defp receipt(announcement_id, []),
    do: %{"announcement_id" => announcement_id, "status" => "success", "bundles" => []}
  defp receipt(announcement_id, failed_bundles),
    do: %{"announcement_id" => announcement_id, "status" => "failed", "bundles" => failed_bundles}

  defp update_tracker(announcement, tracker, success_bundles) do
    relay_id = Map.fetch!(announcement, "relay")

    online_status = case Map.fetch!(announcement, "online") do
                      true -> :online
                      false -> :offline
                    end

    snapshot_status = case Map.fetch!(announcement, "snapshot") do
                        true -> :snapshot
                        false -> :incremental
                      end

    bundle_names = Enum.map(success_bundles, &Map.get(&1, :name)) # Just for logging purposes
    case {online_status, snapshot_status} do
      {:offline, _} ->
        Logger.info("Removing Relay #{relay_id} from active relay list")
        Tracker.remove_relay(tracker, relay_id)
      {:online, :incremental} ->
        Logger.info("Incrementally adding bundles for Relay #{relay_id}: #{inspect bundle_names}")
        Tracker.add_bundles_for_relay(tracker, relay_id, success_bundles)
      {:online, :snapshot} ->
        Logger.info("Setting bundles list for Relay #{relay_id}: #{inspect bundle_names}")
        Tracker.set_bundles_for_relay(tracker, relay_id, success_bundles)
    end
  end

  # If `config` exists in the database (by name), retrieves the
  # database record. If not, installs the bundle and returns the
  # database record.
  defp lookup_or_install(%{"bundle" => %{"name" => name}} = config) do
    case Repo.get_by(Bundle, name: name) do
      %Bundle{}=bundle ->
        {:ok, bundle}
      nil ->
        Logger.info("Installing bundle: #{name}")
        # TODO: Eventually the manifest can go away, as it's not really
        # needed on the bot side of things. Until then, we can fake it
        # with an empty map
        case Cog.Bundle.Install.install_bundle(%{name: name, config_file: config,
                                                 manifest_file: %{}}) do
          {:ok, bundle} ->
            {:ok, bundle}
          {:error, error} ->
            Logger.error("Error! Unable to install bundle `#{name}`: #{inspect error}")
            {:error, name}
        end
    end
  end

  defp random_active_relay(tracker, bundle) do
    case Tracker.active_relays(tracker, bundle) do
      [] -> nil
      relays -> Enum.random(relays)
    end
  end

end
