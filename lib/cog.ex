defmodule Cog do
  require Logger
  use Application

  import Supervisor.Spec, warn: false

  def start(_type, _args) do
    sanity_check()
    adapter_supervisor = get_adapter_supervisor!()
    children = build_children(Mix.env, System.get_env("NOCHAT"), adapter_supervisor)

    opts = [strategy: :one_for_one, name: Cog.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @doc "The name of the embedded command bundle."
  def embedded_bundle, do: "operable"

  @doc "The name of the site namespace."
  def site_namespace, do: "site"

  defp build_children(:dev, nochat, _) when nochat != nil do
    [supervisor(Cog.Endpoint, []),
     worker(Cog.Repo, []),
     worker(Cog.TokenReaper, [])]
  end
  defp build_children(_, _, adapter_supervisor) do
    [supervisor(Cog.Endpoint, []),
     worker(Cog.BusDriver, [], shutdown: 10000),
     worker(Cog.Repo, []),
     worker(Cog.TokenReaper, []),
     worker(Cog.TemplateCache, []),
     worker(Carrier.CredentialManager, []),
     supervisor(Cog.Relay.RelaySup, []),
     supervisor(Cog.Command.CommandSup, []),
     supervisor(adapter_supervisor, [])]
  end

  defp get_adapter_supervisor!() do
    adapter = Application.get_env(:cog, :adapter)
    Logger.info "Using #{adapter} chat adapter"

    case adapter_module(String.downcase(adapter)) do
      {:ok, module} ->
        supervisor = Module.concat(module, "Supervisor")

        case Code.ensure_loaded(supervisor) do
          {:module, module} ->
            module
          {:error, _} ->
            raise RuntimeError, "#{inspect(supervisor)} was not found. Please define a supervisor for the #{adapter} adapter"
        end
      {:error, msg} ->
        raise RuntimeError, "Please configure a chat adapter before starting cog. #{msg}"
    end
  end

  def adapter_module("slack"), do: {:ok, Cog.Adapters.Slack}
  def adapter_module("hipchat"), do: {:ok, Cog.Adapters.HipChat}
  def adapter_module("null"), do: {:ok, Cog.Adapters.Null}
  def adapter_module("test"), do: {:ok, Cog.Adapters.Test}
  def adapter_module(bad_adapter) do
    {:error, "The adapter is set to '#{bad_adapter}', but I don't know what that is. Try 'slack' or 'hipchat' instead."}
  end

  defp sanity_check() do
    {smp_status, smp_message} = verify_smp()
    {ds_status, ds_message} = verify_dirty_schedulers()
    if smp_status == :ok do
      Logger.info(smp_message)
    else
      Logger.error(smp_message)
    end
    if ds_status == :ok do
      Logger.info(ds_message)
    else
      Logger.error(ds_message)
    end
    unless smp_status == :ok and ds_status == :ok do
      Logger.error("Application start aborted.")
      :init.stop()
    end
  end

  defp verify_smp() do
    if :erlang.system_info(:schedulers_online) < 2 do
      {:error, "SMP support disabled. Add '-smp enable' to $ERL_OPTS and restart Cog."}
    else
      {:ok, "SMP support enabled."}
    end
  end

  defp verify_dirty_schedulers() do
    try do
      :erlang.system_info(:dirty_cpu_schedulers)
      {:ok, "Dirty CPU schedulers enabled."}
    rescue
      ArgumentError ->
        {:error, """
Erlang VM is missing support for dirty CPU schedulers.
See http://erlang.org/doc/installation_guide/INSTALL.html for information on enabling dirty scheduler support.
"""}
    end
  end
end
