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
    reset_mnesia_data()
    case configure_message_bus() do
      {:ok, [app_name]} ->
        case Application.ensure_all_started(app_name) do
          :ok ->
            {:ok, app_name}
          error ->
            error
        end
      error ->
        Logger.error("Message bus configuration error: #{inspect error}")
        {:stop, :shutdown}
    end
  end

  def terminate(_, app_name) do
    Application.stop(app_name)
  end

  defp configure_message_bus() do
    case prepare_bindings() do
      {:ok, common_bindings, cert_bindings} ->
        case load_private_config("common_mqtt") do
          {:ok, _} ->
            if length(cert_bindings) == 2 do
              # SSL enabled
              Logger.info("Message bus configured for SSL")
              load_private_config("ssl_mqtt", [{:mqtt_type, :mqtts}|common_bindings] ++ cert_bindings)
            else
              # SSL disabled
              Logger.info("Message bus configured for plain TCP")
              load_private_config("plain_mqtt", [{:mqtt_type, :mqtt}|common_bindings])
            end
          error ->
            error
        end
      error ->
        error
    end
  end

  defp prepare_bindings() do
    bus_opts = Application.get_env(:cog, :message_bus)
    case prepare_host(Keyword.get(bus_opts, :host, "127.0.0.1")) do
      {:ok, mqtt_host} ->
        mqtt_port = Keyword.get(bus_opts, :port, 1883)
        cert_file = Keyword.get(bus_opts, :ssl_cert) |> convert_string
        key_file = Keyword.get(bus_opts, :ssl_key) |> convert_string
        common = [mqtt_addr: mqtt_host,
                  mqtt_port: mqtt_port]
        cond do
          cert_file != nil and key_file != nil ->
            {:ok, common, [cert: cert_file, key: key_file]}
          cert_file == nil and key_file == nil ->
            {:ok, common, []}
          cert_file == nil ->
            Logger.error("Message bus SSL configuration error. Path to certificate file is empty.")
            {:error, {:missing_config, :cert_file}}
          key_file == nil ->
            Logger.error("Message bus SSL configuration error. Path to key file is empty.")
            {:error, {:missing_config, :key_file}}
        end
      error ->
        error
    end
  end

  defp convert_string(nil), do: nil
  defp convert_string(value), do: String.to_charlist(value)

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

  defp prepare_host(host) when is_binary(host),
    do: prepare_host(String.to_charlist(host))
  defp prepare_host(host) do
    case :inet.getaddr(host, :inet) do
      {:ok, addr} ->
        {:ok, addr}
      {:error, v4_error} ->
        {:error, "#{host}: #{:inet.format_error(v4_error)}"}
    end
  end

  defp reset_mnesia_data() do
    mnesia_dir = :mnesia.system_info(:directory) |> String.Chars.to_string
    File.rm_rf!(mnesia_dir)
  end

end
