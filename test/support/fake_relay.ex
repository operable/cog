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
    alias Cog.Messages.RelayInfo
    alias Cog.Messages.Relay.ListBundles

    all = fn(:get, data, next) ->
      Enum.map(data, next)
    end

    reply_to = "bot/test_relays_info/#{relay.id}"
    payload = %RelayInfo{list_bundles: %ListBundles{relay_id: relay.id,
                                                    reply_to: reply_to}}

    response = publish_and_wait(conn, payload, reply_to, @relay_info_topic)
    |> Cog.Messages.Relay.BundleResponse.decode!


    # TODO: With more structure, we can simplify this
    bundles = get_in(response.bundles, [all, "config_file"])
    %{fake_relay | bundles: bundles}
  end
  def get_bundles(%Relay{}=relay) do
    new(relay) |> get_bundles
  end

  @doc """
  Announces the relay to Cog. Puts an announcement message on the bus.
  """
  def announce(%__MODULE__{conn: conn, relay: relay, bundles: bundles}=fake_relay) do
    alias Cog.Messages.Relay.Announce
    alias Cog.Messages.Relay.Announcement

    reply_to = "bot/test_relays/#{relay.id}"


    bundles = bundles
    |> Enum.map(fn(b) ->
      %Cog.Messages.Relay.Bundle{name: b["name"], version: b["version"]}
    end)

    announcement = %Announce{announce: %Announcement{relay: relay.id,
                                                     bundles: bundles,
                                                     snapshot: true,
                                                     online: true,
                                                     reply_to: reply_to,
                                                     announcement_id: relay.id}}

    publish_and_wait(conn, announcement, reply_to, @relays_discovery_topic)
    fake_relay
  end
  def announce(%Relay{}=relay) do
    new(relay) |> get_bundles |> announce
  end

  defp publish_and_wait(conn, payload, reply_to, routed_by) do
    Messaging.Connection.subscribe(conn, reply_to)
    Messaging.Connection.publish(conn, payload, routed_by: routed_by)
    receive do
      {:publish, ^reply_to, response} ->
        Messaging.Connection.unsubscribe(conn, reply_to)
        response
    after
      @timeout ->
        Messaging.Connection.disconnect(conn)
        raise(RuntimeError, "Timed out waiting for response on #{reply_to}")
    end
  end
end
