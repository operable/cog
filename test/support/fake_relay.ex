defmodule Cog.FakeRelay do

  alias Carrier.Messaging
  alias Cog.Models.Relay

  defstruct [conn: "", relay: %{}, bundles: []]

  @relays_discovery_topic "bot/relays/discover"
  @relay_info_topic "bot/relays/info"
  @timeout 5000

  @moduledoc """
  For testing purposes. This module provides functions for faking a running relay.
  """

  @doc """
  Creates a "new" FakeRelay. Connects to the message bus and returns a tuple
  containing the connections and the relay model.
  """
  def new(%Relay{}=relay) do
    {:ok, conn} = Messaging.Connection.connect()
    %__MODULE__{conn: conn, relay: relay}
  end

  @doc """
  Gets the bundle list from Relay.Info
  """
  def get_bundles(%__MODULE__{conn: conn, relay: relay}=fake_relay) do
    all = fn(:get, data, next) ->
      Enum.map(data, next)
    end

    reply_to = "bot/test_relays/#{relay.id}"

    Messaging.Connection.subscribe(conn, reply_to)

    payload = %{"list_bundles" => %{"relay_id" => relay.id,
                                    "reply_to" => reply_to}}

    Messaging.Connection.publish(conn, payload, routed_by: @relay_info_topic)

    receive do
      {:publish, ^reply_to, response} ->
        json = Poison.decode!(response)
        Messaging.Connection.unsubscribe(conn, reply_to)
        bundles = get_in(json, ["bundles", all, "config_file"])
        %{fake_relay | bundles: bundles}
    after
      @timeout ->
        :emqttc.disconnect(conn)
        raise(RuntimeError, "Timed out waiting for a reply from relay info")
    end
  end

  @doc """
  Announces the relay to Cog. Puts an announcement message on the bus.
  """
  def announce(%__MODULE__{conn: conn, relay: relay, bundles: bundles}=fake_relay) do
    reply_to = "bot/test_relays/#{relay.id}"
    Messaging.Connection.subscribe(conn, reply_to)
    announcement = %{"announce" => %{"relay" => relay.id,
                                     "bundles" => bundles,
                                     "snapshot" => true,
                                     "online" => true,
                                     "reply_to" => reply_to,
                                     "announcement_id" => relay.id}}
    Messaging.Connection.publish(conn, announcement, routed_by: @relays_discovery_topic)

    receive do
      {:publish, ^reply_to, _response} ->
        Messaging.Connection.unsubscribe(conn, reply_to)
        fake_relay
    after
      @timeout ->
        :emqttc.disconnect(conn)
        raise(RuntimeError, "Timed out waiting for announcement receipt")
    end
  end
end
