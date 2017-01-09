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
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    case configure_message_bus() do
      :ok ->
        case Application.ensure_all_started(:emqttd) do
          {:ok, _} ->
            :erlang.process_flag(:trap_exit, true)
            {:ok, :emqttd}
          error ->
            {:stop, error}
        end
      error ->
        Logger.error("Message bus configuration error: #{inspect error}")
        {:stop, :shutdown}
    end
  end

  def terminate(_, _) do
    Application.stop(:emqttd)
    Application.stop(:esockd)
  end

  defp configure_message_bus() do
    case prepare_bindings() do
      {:ok, common_bindings, cert_bindings} ->
        case eval_config("common_mqtt", common_bindings) do
          {:ok, base} ->
            case configure_listeners(common_bindings ++ cert_bindings) do
              {:ok, listeners} ->
                final_config = merge_config(base, listeners)
                Enum.each(final_config, fn({key, value}) -> :application.set_env(:emqttd, key, value, [persistent: true]) end)
                :ok
              error ->
                error
            end
          error ->
            error
        end
      error ->
        error
    end
  end

  defp merge_config(c1, c2) do
    c1v = Keyword.fetch!(c1, :emqttd)
    c2v = Keyword.fetch!(c2, :emqttd)
    c1v ++ c2v
  end

  defp configure_listeners(bindings) do
    if length(bindings) == 4 do
      # SSL enabled
      Logger.info("Message bus configured for SSL")
      eval_config("ssl_mqtt", [{:mqtt_type, :mqtts}|bindings])
    else
      # SSL disabled
      Logger.info("Message bus configured for plain TCP")
      eval_config("plain_mqtt", [{:mqtt_type, :mqtt}|bindings])
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

  def eval_config(name, bindings) do
    config = File.read!(Path.join([:code.priv_dir(:cog), "config", name <> ".conf"]))
    try do
      {results, _} = Code.eval_string(config, bindings)
      {:ok, results}
    rescue
      e ->
        {:error, Exception.message(e)}
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

end
