defmodule Cog.CoreSup do
  require Logger
  use Supervisor

  def start_link() do
    Supervisor.start_link(__MODULE__, [])
  end

  def init(_) do
    adapter_supervisor = get_adapter_supervisor!()
    children = [worker(Cog.TokenReaper, []),
                supervisor(Cog.Relay.RelaySup, []),
                supervisor(Cog.Command.CommandSup, []),
                supervisor(adapter_supervisor, []),
                supervisor(Cog.Endpoint, []),
                supervisor(Cog.TriggerEndpoint, []),
                supervisor(Cog.ServiceEndpoint, []),
                supervisor(Cog.Adapters.Http.Supervisor,[])]
    {:ok, {%{strategy: :one_for_one, intensity: 10, period: 60}, children}}
  end

  defp get_adapter_supervisor!() do
    case Cog.chat_adapter_module do
      {:ok, adapter} ->
        Logger.info "Using #{inspect adapter} chat adapter"
        supervisor = Module.concat(adapter, "Supervisor")

        case Code.ensure_loaded(supervisor) do
          {:module, ^supervisor} ->
            supervisor
          {:error, _} ->
            raise RuntimeError, "#{inspect(supervisor)} was not found. Please define a supervisor for the #{inspect(adapter)} adapter"
        end
      {:error, {:bad_adapter, bad_adapter}} ->
        raise RuntimeError, "The adapter is set to #{inspect(bad_adapter)}, but I don't know what that is. Try one of the following values instead: #{Enum.map_join(Map.keys(Cog.chat_adapters), ", ", &inspect/1)}"
    end
  end


end
