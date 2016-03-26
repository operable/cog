defmodule Cog do
  require Logger
  use Application

  import Supervisor.Spec, warn: false

  @adapters %{"slack"   => Cog.Adapters.Slack,
              "hipchat" => Cog.Adapters.HipChat,
              "irc"     => Cog.Adapters.IRC,
              "null"    => Cog.Adapters.Null,
              "test"    => Cog.Adapters.Test}

  def start(_type, _args) do
    adapter_supervisor = get_adapter_supervisor!()
    children = build_children(Mix.env, System.get_env("NOCHAT"), adapter_supervisor)

    opts = [strategy: :one_for_one, name: Cog.Supervisor]
    case Supervisor.start_link(children, opts) do
      {:ok, top_sup} ->
        # Verify the latest schema migration after starting the database worker
        {sm_status, sm_message} = verify_schema_migration()
        log_message(sm_status, sm_message)
        if sm_status == :error do
          abort_cog()
        else
          {:ok, top_sup}
        end
      error ->
        error
    end
  end

  @doc "The name of the embedded command bundle."
  def embedded_bundle, do: "operable"

  @doc "The name of the site namespace."
  def site_namespace, do: "site"

  @doc """
  Returns the currently configured chat adapter module, if found.
  """
  @spec adapter_module :: {:ok, module} | {:error, {:bad_adapter, String.t}}
  def adapter_module do
    configured = Application.get_env(:cog, :adapter)
    case adapter_module(configured) do
      {:ok, adapter} ->
        {:ok, adapter}
      {:error, {:bad_adapter, _}} ->
        {:error, {:bad_adapter, configured}}
    end
  end

  @doc """
  For a given adapter name return the implementing module, if it
  exists.
  """
  @spec adapter_module(String.t) :: {:ok, module} | {:error, {:bad_adapter, String.t}}
  def adapter_module(name) do
    case Map.fetch(@adapters, name) do
      {:ok, module} ->
        {:ok, module}
      :error ->
        {:error, {:bad_adapter, name}}
    end
  end

  ########################################################################

  defp build_children(:dev, nochat, _) when nochat != nil do
    [worker(Cog.Repo, []),
     worker(Cog.TokenReaper, []),
     supervisor(Cog.Endpoint, [])]
  end
  defp build_children(_, _, adapter_supervisor) do
    [worker(Cog.Repo, []),
     worker(Cog.BusDriver, [], shutdown: 10000),
     worker(Cog.TokenReaper, []),
     worker(Cog.TemplateCache, []),
     worker(Carrier.CredentialManager, []),
     supervisor(Cog.Relay.RelaySup, []),
     supervisor(Cog.Command.CommandSup, []),
     supervisor(adapter_supervisor, []),
     supervisor(Cog.Endpoint, [])]
  end

  defp get_adapter_supervisor!() do
    case adapter_module do
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
        raise RuntimeError, "The adapter is set to #{inspect(bad_adapter)}, but I don't know what that is. Try one of the following values instead: #{Enum.map_join(Map.keys(@adapters), ", ", &inspect/1)}"
    end
  end

  defp log_message(:ok, message), do: Logger.info(message)
  defp log_message(:error, message), do: Logger.error(message)
  defp log_message(_status, message), do: Logger.warn(message)

  defp verify_schema_migration() do
    cond do
      migration_needed? and Mix.env == :dev ->
        {:dev, "The migration schema is not synchronized. Allowing to continue in the development environment."}
      migration_needed? ->
        {:error, "The migration schema is not up-to-date. Please perform a migration and restart Cog."}
      true ->
        {:ok, "Schema is at the current version"}
    end
  end

  defp migration_needed?() do
    [last_file_version, _] = Path.join([:code.priv_dir(:cog), "repo", "migrations"])
    |> File.ls!
    |> Enum.max
    |> String.split("_", parts: 2)

    last_db_version = Enum.max(Ecto.Migration.SchemaMigration.migrated_versions(Cog.Repo, "public"))

    if last_db_version != String.to_integer(last_file_version) do
      true
    else
      false
    end
  end

  defp abort_cog() do
    Logger.error("Application start aborted.")
    Logger.flush()
    :init.stop()
  end
end
