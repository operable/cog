defmodule Cog.BusDriver do
  @moduledoc """
  BusDriver is responsible for configuring, starting, and stopping  Cog's embedded
  message bus.

  ## Configuration
  BusDriver can be configured with the following configuration parameters.

  `:host` - Listen host name or IP address. Defaults to `"127.0.0.1"`.
  `:port` - List port. Defaults to `1883`.
  `:cert_file` - Path to SSL certificate file. Required for SSL support.
  `:key_file` - Path to SSL key file. Required for SSL support.

  ## Example configuration
  ```config :cog, :message_bus,
  host: "192.168.1.133",
  port: 10883,
  cert_file: "/etc/cog/ssl.cert",
  key_file: "/etc/cog/ssl.key"
  """

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
        cond do
          # SSL enabled
          cert_file != nil and key_file != nil ->
            Logger.info("Message bus configured for SSL")
            load_private_config("ssl_mqtt", [cert: String.to_char_list(cert_file),
                                             key: String.to_char_list(key_file),
                                             mqtt_type: :mqtts] ++ bindings)
          # SSL disabled
          cert_file == nil and key_file == nil ->
            Logger.info("Message bus configured for plain TCP")
            load_private_config("plain_mqtt", [{:mqtt_type, :mqtt}|bindings])
          # SSL misconfigured (either cert_file is nil or key_file is nil)
          true ->
            if cert_file == nil do
              Logger.error("Message bus SSL configuration error. Path to certificate file is empty.")
              {:error, {:missing_config, :cert_file}}
            else
              Logger.error("Message bus SSL configuration error. Path to key file is empty.")
              {:error, {:missing_config, :key_file}}
            end
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
