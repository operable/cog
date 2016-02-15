defmodule Integration.RelayTest do
  use Cog.AdapterCase, adapter: "slack"
  alias Carrier.Messaging

  @moduletag :slack

  @relays_discovery_topic "bot/relays/discover"

  setup do
    user = user("botci")
    |> with_chat_handle_for("slack")

    {:ok, %{user: user}}
  end

  test "running command from newly installed bundle", %{user: user} do
    conn = subscribe_to_relay_discover

    checkout_relay
    build_relay
    port = start_relay
    wait_for_relay

    checkout_mist
    build_mist
    install_mist
    wait_for_mist

    message = send_message user, "@deckard: help mist:ec2-find"
    assert_response """
      Documentation for `mist:ec2-find`

      mist:ec2-find --region=&lt;region&gt; [--state | --tags | --ami | --return=(id,pubdns,privdns,state,keyname,ami,kernel,arch,vpc,pubip,privip,az,tags)]

    """, after: message

    stop_relay(port)
    disconnect_from_relay_discover(conn)
  end

  def checkout_relay do
    Mix.SCM.Git.checkout(dest: "../cog_relay", git: "git@github.com:operable/relay.git")
  end

  def checkout_mist do
    Mix.SCM.Git.checkout(dest: "../cog_mist", git: "git@github.com:operable/mist.git")
  end

  def build_relay do
    System.cmd("mix", ["deps.get"], cd: "../cog_relay")
  end

  def start_relay do
    Port.open({:spawn, "iex -S mix"}, cd: "../cog_relay", env: [{'COG_MQTT_PORT', '1884'}])
  end

  def stop_relay(port) do
    {:os_pid, os_pid} = Port.info(port, :os_pid)
    System.cmd("kill", ["-9", to_string(os_pid)])
  end

  def build_mist do
    System.cmd("make", [], cd: "../cog_mist")
  end

  def install_mist do
    System.cmd("cp", ["mist.cog", "../cog_relay/data/pending"], cd: "../cog_mist")
  end

  def subscribe_to_relay_discover do
    {:ok, conn} = Messaging.Connection.connect
    Messaging.Connection.subscribe(conn, @relays_discovery_topic)
    conn
  end

  def wait_for_relay do
    receive do
      {:publish, @relays_discovery_topic, message} ->
        message = Poison.decode!(message)

        case match?(%{"data" => %{"intro" => _relay}}, message) do
          true  -> true
          false -> wait_for_relay
        end
    end
  end

  def wait_for_mist do
    receive do
      {:publish, @relays_discovery_topic, message} ->
        message = Poison.decode!(message)

        case match?(%{"data" => %{"announce" => %{"bundles" => [%{"bundle" => %{"name" => "mist"}}]}}}, message) do
          true  -> true
          false -> wait_for_mist
        end
    end
  end

  def disconnect_from_relay_discover(conn) do
    :emqttc.disconnect(conn)
  end
end
