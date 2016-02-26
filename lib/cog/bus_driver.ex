defmodule Cog.BusDriver do

  require Logger
  use GenServer

  def start_link() do
    GenServer.start_link(__MODULE__, [])
  end

  def init(_) do
    case configure_message_bus() do
      {:ok, [app_name]} ->
        Application.start(app_name)
        {:ok, app_name}
      error ->
        Logger.error("Message bus configuration error: #{inspect error}")
        {:stop, :shutdown}
    end
  end

  def terminate(_, app_name) do
    Application.stop(app_name)
  end

  defp configure_message_bus() do
    bus_opts = Application.get_env(:cog, :message_bus)
    mqtt_host = Keyword.get(bus_opts, :host, "127.0.0.1")
    mqtt_port = Keyword.get(bus_opts, :port, 1883)
    cert_file = Keyword.get(bus_opts, :ssl_cert)
    key_file = Keyword.get(bus_opts, :ssl_key)
    bindings = [mqtt_addr: mqtt_host, mqtt_port: mqtt_port]
    case load_private_config("common_mqtt") do
      {:ok, _} ->
        if cert_file != nil and key_file != nil do
          Logger.info("Message bus configured for SSL")
          load_private_config("ssl_mqtt", [cert: String.to_char_list(cert_file),
                                           key: String.to_char_list(key_file),
                                           mqtt_type: :mqtts] ++ bindings)
        else
          Logger.info("Message bus configured for plain TCP")
          load_private_config("plain_mqtt", [{:mqtt_type, :mqtt}|bindings])
        end
      error ->
        error
    end
  end

  defp load_private_config(name, bindings \\ []) do
    config = File.read!(Path.join([:code.priv_dir(:cog), "config", name <> ".exs"]))
    case Code.eval_string(config, bindings) do
      {:ok, results} ->
        [{_, agent}|_] = Enum.reverse(results)
        config = Mix.Config.Agent.get(agent)
        Mix.Config.Agent.stop(agent)
        Mix.Config.validate!(config)
        {:ok, Mix.Config.persist(config)}
      error ->
        error
    end
  end

end
