defmodule Cog.Relay.Info do

  @relay_info_topic "bot/relays/info"

  @moduledoc """
  Subscribes on #{@relay_info_topic} to provide info to relays
  on request. Relays can publish the following special messages
  on the topic:

  list bundles - Returns the list of bundles assigned to the relay.
    message: {"list_bundles": {"relay_id": <relay uuid>, "reply_to": <reply topic>}}
    response: {"bundles": [<bundles>]}
  """

  defstruct [mq_conn: nil]

  use Adz
  use GenServer

  alias Carrier.Messaging
  alias Cog.Repo
  alias Cog.Models.Relay
  alias Cog.Repository.Bundles
  alias Cog.Util.Hash

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    case Messaging.Connection.connect() do
      {:ok, conn} ->
        Logger.info("Starting relay information service")
        Messaging.Connection.subscribe(conn, @relay_info_topic)
        {:ok, %__MODULE__{mq_conn: conn}}
      error ->
        Logger.error("Error starting relay info: #{inspect error}")
        error
    end
  end

  def handle_info({:publish, @relay_info_topic, compressed}, state) do
    {:ok, message} = :snappy.decompress(compressed)
    case Poison.decode(message) do
      {:ok, %{"list_bundles" => message}} ->
        info(message, state)
        {:noreply, state}
      {:ok, %{"get_dynamic_configs" => message}} ->
        get_dynamic_configs(message, state)
        {:noreply, state}
      error ->
        Logger.error("Error decoding json: #{inspect error}")
        {:noreply, state}
    end
  end
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  #################################################################
  # Private functions

  defp info(%{"relay_id" => relay_id, "reply_to" => reply_to}, state) do
    # TODO: consider getting rid of this Repo.get call altogether,
    # particularly in light of the note in the `nil` branch of the
    # case statement below

    # Only send data if reply_to topic matches relay_id
    if id_matches_reply_to(relay_id, reply_to) do
      case Repo.get(Relay, relay_id) do
        %Relay{} ->
          bundles = relay_id
          |> Cog.Repository.Bundles.bundle_configs_for_relay
          |> Enum.map(&(%{config_file: &1}))

          respond(%{bundles: bundles}, reply_to, state)
        nil ->
          ## If we get a nil back then the relay isn't registered with Cog.
          ## Technically we should never respond with an error, because relays
          ## should never make it through the BusEnforcer if they aren't registered
          ## but for completeness it's included here.
          respond(%{error: "Relay with id #{relay_id} was not recognized."}, reply_to, state)
      end
    end
  end

  defp get_dynamic_configs(%{"relay_id" => relay_id, "config_hash" => config_hash, "reply_to" => reply_to}, state) do
    # Only send data if the reply_to topic matches relay_id
    if id_matches_reply_to(relay_id, reply_to) do
      configs = Bundles.dynamic_configs_for_relay(relay_id) |> Enum.map(&(%{bundle_name: &1.bundle.name,
                                                                            config: &1.config,
                                                                            hash: &1.hash}))
      signature = calculate_signature(configs)
      if config_hash != signature do
        respond(%{configs: configs, changed: true, signature: signature}, reply_to, state)
      else
        respond(%{changed: false}, reply_to, state)
      end
    end
  end

  defp respond(payload, reply_to, state) do
    Messaging.Connection.publish(state.mq_conn, payload, routed_by: reply_to)
  end

  defp calculate_signature(configs) do
    configs
    |> Enum.sort(&(&1.bundle.name <= &2.bundle.name))
    |> Enum.map(&(&1.hash))
    |> Hash.compute_hash
  end

  defp id_matches_reply_to(relay_id, reply_to) do
    # Assumes reply_to topics are of form "bot/relays/<relay_id>/blah[/...]
    case String.split(reply_to, "/", parts: 4) do
      [_, _, ^relay_id|_] ->
        true
      _ ->
        false
    end
  end

end
