defmodule Cog.Relay.Info do

  defstruct [mq_conn: nil]

  use Adz
  use GenServer

  alias Carrier.Messaging
  alias Cog.Repo
  alias Cog.Models.Relay
  alias Cog.Queries

  @relay_info_topic "bot/relays/info"

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

  def handle_info({:publish, @relay_info_topic, message}, state) do
    case Poison.decode(message) do
      {:ok, json} ->
        info(json, state)
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

  defp info(%{"list_bundles" => %{"relay_id" => relay_id, "reply_to" => reply_to}}, state) do
    case Repo.one(Queries.Relay.for_id(relay_id)) do
      %Relay{}=relay ->
        Enum.flat_map(relay.groups, &(&1.bundles))
        |> prepare_bundles
      nil ->
        []
    end
    |> respond(reply_to, state)
  end

  defp prepare_bundles(bundles) do
    prepared_bundles = Enum.map(bundles, fn(bundle) ->
      %{name: bundle.name,
        config_file: bundle.config_file,
        manifest_file: bundle.manifest_file,
        enabled: bundle.enabled}
    end)

    %{bundles: prepared_bundles}
  end

  defp respond(payload, reply_to, state) do
    Messaging.Connection.publish(state.mq_conn, payload, routed_by: reply_to)
  end
end
