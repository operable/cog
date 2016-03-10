defmodule Integration.RelayTest do
  use Cog.AdapterCase, adapter: "test"
  alias Carrier.Messaging

  @moduletag :relay

  @relays_discovery_topic "bot/relays/discover"
  @timeout 60000 # 60 seconds

  setup do
    user = user("botci")
    |> with_chat_handle_for("test")

    conn = subscribe_to_relay_discover

    checkout_relay
    build_relay
    os_pid = start_relay
    wait_for_relay(conn)

    checkout_mist
    build_mist
    install_mist
    wait_for_mist(conn)

    on_exit(fn ->
      stop_relay(os_pid)
      disconnect_from_relay_discover(conn)
    end)

    {:ok, %{user: user}}
  end

  test "running command from newly installed bundle", %{user: user} do
    response = send_message(user, "@bot: help mist:ec2-find")
    assert response["data"]["response"] == """
    {
      "documentation": "mist:ec2-find --region=<region> [--state | --tags | --ami | --return=(id,pubdns,privdns,state,keyname,ami,kernel,arch,vpc,pubip,privip,az,tags)]",
      "command": "mist:ec2-find"
    }
    """ |> String.rstrip
  end

  # Runs `rm -rf` on the path before checking out the repo
  defp checkout(name) do
    Mix.SCM.Git.checkout(dest: "../cog_#{name}", git: "git@github.com:operable/#{name}.git")
  end

  defp checkout_relay do
    checkout("relay")
  end

  defp checkout_mist do
    checkout("mist")
  end

  defp build_relay do
    System.cmd("mix", ["deps.get"], cd: "../cog_relay")
  end

  defp start_relay do
    port = Port.open({:spawn, "iex -S mix"}, cd: "../cog_relay", env: [{'COG_MQTT_PORT', '1884'}])
    {:os_pid, os_pid} = Port.info(port, :os_pid)
    os_pid
  end

  defp stop_relay(os_pid) do
    System.cmd("kill", ["-9", to_string(os_pid)])
  end

  defp build_mist do
    System.cmd("make", ["install"], cd: "../cog_mist")
    System.cmd("make", [], cd: "../cog_mist")
  end

  defp install_mist do
    System.cmd("cp", ["mist.cog", "../cog_relay/data/pending"], cd: "../cog_mist")
  end

  defp subscribe_to_relay_discover do
    {:ok, conn} = Messaging.Connection.connect
    Messaging.Connection.subscribe(conn, @relays_discovery_topic)
    conn
  end

  defp wait_for_relay(conn) do
    receive do
      {:publish, @relays_discovery_topic, message} ->
        message = Poison.decode!(message)

        case match?(%{"data" => %{"intro" => _relay}}, message) do
          true  -> true
          false -> wait_for_relay(conn)
        end
    after @timeout ->
      disconnect_from_relay_discover(conn)
      raise(RuntimeError, "Connection timeout out waiting for relay to start")
    end
  end

  defp wait_for_mist(conn) do
    receive do
      {:publish, @relays_discovery_topic, message} ->
        message = Poison.decode!(message)

        case match?(%{"data" => %{"announce" => %{"bundles" => [%{"bundle" => %{"name" => "mist"}}]}}}, message) do
          true  -> true
          false -> wait_for_mist(conn)
        end
    after @timeout ->
      disconnect_from_relay_discover(conn)
      raise(RuntimeError, "Connection timeout out waiting for mist to be installed")
    end
  end

  defp disconnect_from_relay_discover(conn) do
    :emqttc.disconnect(conn)
  end
end
