defmodule Cog.Relay.Relays do

  defstruct [mq_conn: nil, relays: %{}]

  use Adz
  use GenServer

  alias Carrier.Credentials
  alias Carrier.CredentialManager
  alias Carrier.Messaging
  alias Cog.Models.Bundle
  alias Cog.Repo

  @relays_discovery_topic "bot/relays/discover"

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def pick_one(bundle) do
    GenServer.call(__MODULE__, {:random_relay, bundle}, :infinity)
  end

  def drop_bundle(bundle) do
    GenServer.call(__MODULE__, {:drop_bundle, bundle}, :infinity)
  end

  def init(_) do
    case Messaging.Connection.connect() do
      {:ok, conn} ->
        Logger.info("Starting")
        Messaging.Connection.subscribe(conn, @relays_discovery_topic)
        # Seed RNG so picking relays at random works
        :random.seed(:os.timestamp())
        {:ok, %__MODULE__{relays: %{}, mq_conn: conn}}
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
  def handle_call({:random_relay, bundle}, _from, %__MODULE__{relays: relays}=state) do
    relay = case relays_for_bundle(relays, bundle) do
              [] -> nil
              choices -> Enum.random(choices)
            end
    {:reply, relay, state}
  end
  def handle_call({:drop_bundle, bundle}, _from, %__MODULE__{relays: relays}=state) do
    relays = drop_relays_for_bundle(relays, bundle)
    {:reply, :ok, %{state | relays: relays}}
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

  defp process_announcement(announcement, %__MODULE__{relays: relays}=state) do
    id = Map.fetch!(announcement, "relay")
    online_status = case Map.fetch!(announcement, "online") do
                      true -> :online
                      false -> :offline
                    end
    bundles = Map.fetch!(announcement, "bundles")
    snapshot_status = case Map.fetch!(announcement, "snapshot") do
                        true -> :snapshot
                        false -> :incremental
                      end

    install_new_bundles(bundles)

    # For now, only track the names of bundles a particular relay
    # knows about
    bundle_names = Enum.map(bundles, &bundle_name/1)

    updated_relays = case {online_status, snapshot_status, Map.get(relays, id, [])} do
                       {:offline, _, _} ->
                         Logger.info("Removing Relay #{id} from active relay list")
                         Map.delete(relays, id)
                       {:online, :incremental, existing} ->
                         Logger.info("Incrementally adding bundles for Relay #{id}: #{inspect bundle_names}")
                         Map.put(relays, id, (bundle_names |> Enum.concat(existing) |> Enum.uniq))
                       {:online, :snapshot, _} ->
                         Logger.info("Setting bundles list for Relay #{id}: #{inspect bundle_names}")
                         Map.put(relays, id, bundle_names)
                     end
    case Map.fetch(announcement, "reply_to")  do
      :error ->
        :ok # The embedded bundle has no need for a reply
      {:ok, reply_to} ->
        # If the message has a `reply_to` field, it must also have an
        # `announcement_id` field
        announcement_id = Map.fetch!(announcement, "announcement_id")
        receipt = receipt(announcement_id)
        Logger.debug("Sending receipt to #{reply_to}: #{inspect receipt}")
        Messaging.Connection.publish(state.mq_conn, receipt, routed_by: reply_to)
    end
    %{state | relays: updated_relays}
  end

  defp receipt(announcement_id),
    do: %{"acknowledged" => announcement_id}


  defp install_new_bundles(bundles) do
    bundles
    |> Enum.reject(&known_bundle?/1)
    |> Enum.each(&install/1)
  end

  defp install(%{"bundle" => %{"name" => bundle_name}}=config) do
    Logger.info("Installing bundle: #{bundle_name}")
    # TODO: Eventually the manifest can go away, as it's not really
    # needed on the bot side of things. Until then, we can fake it
    # with an empty map
    Cog.Bundle.Install.install_bundle(%{name: bundle_name,
                                         config_file: config,
                                         manifest_file: %{}})
  end

  # Is the bundle represented by this config in the database yet?
  defp known_bundle?(config) do
    case Repo.get_by(Bundle, name: bundle_name(config)) do
      nil -> false
      %Bundle{} -> true
    end
  end

  # Extract a bundle name from a configuration map
  defp bundle_name(%{"bundle" => %{"name" => name}}),
    do: name

  # Create a list of all relays that know about the given bundle
  defp relays_for_bundle(relays, bundle_name) do
    Enum.reduce(relays, [],
      fn({relay, bundles}, acc) ->
        case Enum.member?(bundles, bundle_name) do
          true -> [relay | acc]
          false -> acc
        end
      end)
  end

  defp drop_relays_for_bundle(relays, bundle_name) do
    Enum.reduce(relays, %{},
      fn({relay, bundles}, acc) ->
        Map.put(acc, relay, bundles -- [bundle_name])
      end)
  end

end
