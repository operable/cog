defmodule Cog.Relay.Relays do

  alias Cog.Relay.Tracker

  defstruct [mq_conn: nil,
             tracker: Tracker.new]

  use Adz
  use GenServer

  alias Carrier.Messaging
  alias Cog.Models.Relay
  alias Cog.Repo
  alias Cog.Relay.Util
  alias Cog.Models.BundleVersion

  @relays_discovery_topic "bot/relays/discover"

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Choses a relay at random that is currently actively running `bundle`.

  Returns the relay's ID, or `nil` if no relay is currently running
  `bundle`.
  """
  @spec pick_one(String.t, String.t) :: String.t | nil
  def pick_one(bundle, version),
    do: GenServer.call(__MODULE__, {:random_relay, bundle, version}, :infinity)

  @doc """
  Answers the question "can this relay run this bundle?"
  """
  @spec relay_available?(String.t, String.t, String.t) :: boolean()
  def relay_available?(relay, bundle, version),
    do: GenServer.call(__MODULE__, {:relay_available, relay, bundle, version}, :infinity)

  @doc "Enables the relay"
  @spec enable_relay(%Relay{}) :: :ok
  def enable_relay(%Relay{}=relay) do
    GenServer.call(__MODULE__, {:enable_relay, relay}, :infinity)
  end

  @doc "Disables the relay"
  @spec disable_relay(%Relay{}) :: :ok
  def disable_relay(%Relay{}=relay) do
    GenServer.call(__MODULE__, {:disable_relay, relay}, :infinity)
  end

  @doc "Drops the relay"
  @spec drop_relay(%Relay{}) :: :ok
  def drop_relay(%Relay{}=relay) do
    GenServer.call(__MODULE__, {:drop_relay, relay}, :infinity)
  end

  # TODO: Consider just passing a BundleVersion model here instead
  @doc """
  Returns the IDs of all Relays currently running `bundle_name`. If no
  Relays are running the bundle, an empty list is returned.
  """
  @spec relays_running(String.t, String.t) :: [String.t]
  def relays_running(bundle_name, version),
    do: GenServer.call(__MODULE__, {:relays_running, bundle_name, version}, :infinity)

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

  def handle_call({:announce_embedded_relay, announcement}, _from, state) do
    # This function head acts as a private internal API used for
    # registering the bot as a host for the embedded command
    # bundle. (We don't provide a public API function for this message
    # for that reason.)
    #
    # It is a blocking call, because we want to be assured that the
    # bundle is recorded in the database before proceeding.
    #
    # See `Cog.Bundle.Embedded` for more.
    new_state = process_embedded_announcement(announcement, state)
    {:reply, :ok, new_state}
  end
  def handle_call({:random_relay, bundle, version}, _from, state),
    do: {:reply, random_relay(state.tracker, bundle, version), state}
  def handle_call({:relay_available, relay, bundle, version}, _from, state) do
    {:reply, Tracker.is_bundle_available?(state.tracker, relay, bundle, version), state}
  end
  def handle_call({:enable_relay, relay}, _from, state) do
    tracker = enable_relay(state.tracker, relay.id)
    {:reply, :ok, %{state | tracker: tracker}}
  end
  def handle_call({:disable_relay, relay}, _from, state) do
    tracker = disable_relay(state.tracker, relay.id)
    {:reply, :ok, %{state | tracker: tracker}}
  end
  def handle_call({:drop_relay, relay}, _from, state) do
    tracker = remove_relay(state.tracker, relay.id)
    {:reply, :ok, %{state | tracker: tracker}}
  end
  def handle_call({:relays_running, bundle_name, version} , _from, state),
    do: {:reply, Tracker.relays(state.tracker, bundle_name, version), state}

  def handle_info({:publish, @relays_discovery_topic, message}, state) do
    try do
      payload = Cog.Messages.Relay.Announce.decode!(message)
      # TODO: When this is unwrapped, we can just pass payload directly
      state = process_announcement(payload.announce, state)
      {:noreply, state}
    rescue
      e in Conduit.ValidationError ->
        Logger.error("Failed validation: #{inspect e}")
        {:noreply, state}
    end
  end
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  ########################################################################

  defp process_embedded_announcement(announcement, %__MODULE__{tracker: tracker}=state) do
    [%Cog.Messages.Relay.Bundle{name: name, version: version}] = announcement.bundles
    tracker = update_tracker(announcement, tracker, [{name, version}], true)
    %{state | tracker: tracker}
  end

  defp process_announcement(announcement, %__MODULE__{tracker: tracker}=state) do
    bundles = (announcement.bundles || []) # TODO: Conduit structs need default values
    |> Enum.map(&Map.from_struct/1)

    {success_bundle_versions, failed_bundles} = bundles
    |> Enum.map(&Cog.Repository.Bundles.verify_version_exists/1) # TODO: this is really just a lookup, now; we might be able to simplify this logic
    |> Enum.partition(&Util.is_ok?/1)
    |> Util.unwrap_partition_results

    specs = Enum.map(success_bundle_versions, &version_spec/1)
    tracker = update_tracker(announcement, tracker, specs, false)

    reply_to        = announcement.reply_to
    announcement_id = announcement.announcement_id
    receipt = receipt(announcement_id, failed_bundles)
    Logger.debug("Sending receipt to #{reply_to}: #{inspect receipt}")
    Messaging.Connection.publish(state.mq_conn, receipt, routed_by: reply_to)

    %{state | tracker: tracker}
  end

  defp receipt(announcement_id, []),
    do: %Cog.Messages.Relay.Receipt{announcement_id: announcement_id,
                                    status: "success",
                                    bundles: []}
  defp receipt(announcement_id, failed_bundles),
    do: %Cog.Messages.Relay.Receipt{announcement_id: announcement_id,
                                    status: "failed",
                                    bundles: failed_bundles}

  defp update_tracker(announcement, tracker, specs, internal) do
    relay_id = announcement.relay

    online_status = case announcement.online do
                      true -> :online
                      false -> :offline
                    end

    # TODO: just compare with the ID from credential manager; if it
    # matches, it's the bot itself, and it's always enabled. That lets
    # us dispense with the `internal` boolean

    enabled_status = if internal || relay_enabled?(relay_id) do
                       :enabled
                     else
                       :disabled
                     end

    snapshot_status = case announcement.snapshot do
                        true -> :snapshot
                        false -> :incremental
                      end

    case {online_status, enabled_status} do
      {:offline, _} ->
        remove_relay(tracker, relay_id)
      {:online, :disabled} ->
        load_bundles(snapshot_status, tracker, relay_id, specs)
        |> disable_relay(relay_id)
      {:online, :enabled} ->
        load_bundles(snapshot_status, tracker, relay_id, specs)
        |> enable_relay(relay_id)
    end
  end

  defp random_relay(tracker, bundle, version) do
    case Tracker.relays(tracker, bundle, version) do
      [] -> nil
      relays -> Enum.random(relays)
    end
  end

  defp version_spec(%BundleVersion{}=bv),
    do: {bv.bundle.name, bv.version}

  defp load_bundles(:incremental, tracker, relay_id, specs) do
    Logger.info("Incrementally adding bundles for Relay #{relay_id}: #{inspect specs}")
    Tracker.add_bundle_versions_for_relay(tracker, relay_id, specs)
  end
  defp load_bundles(:snapshot, tracker, relay_id, specs) do
    Logger.info("Setting bundles list for Relay #{relay_id}: #{inspect specs}")
    Tracker.set_bundle_versions_for_relay(tracker, relay_id, specs)
  end

  defp enable_relay(tracker, relay_id) do
    Logger.info("Enabled Relay #{relay_id}")
    Tracker.enable_relay(tracker, relay_id)
  end

  defp disable_relay(tracker, relay_id) do
    Logger.info("Disabled Relay #{relay_id}")
    Tracker.disable_relay(tracker, relay_id)
  end

  defp remove_relay(tracker, relay_id) do
    Logger.info("Removed Relay #{relay_id} from active relay list")
    Tracker.remove_relay(tracker, relay_id)
  end

  defp relay_enabled?(relay_id) do
    case Repo.get(Relay, relay_id) do
      %Relay{enabled: true} -> true
      _ -> false
    end
  end

end
