defmodule Cog do
  require Logger
  use Application

  import Supervisor.Spec, warn: false

  def start(_type, _args) do
    adapter = get_adapter!
    Logger.info "Using #{adapter} chat adapter"

    children = build_children(Mix.env, System.get_env("NOCHAT"), adapter)

    opts = [strategy: :one_for_one, name: Cog.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @doc "The name of the embedded command bundle."
  def embedded_bundle, do: "operable"

  defp build_children(:dev, nochat, _) when nochat != nil do
    [supervisor(Cog.Endpoint, []),
     worker(Cog.Repo, []),
     worker(Cog.TokenReaper, [])]
  end
  defp build_children(_, _, adapter) do
    [supervisor(Cog.Endpoint, []),
     worker(Cog.Repo, []),
     worker(Cog.TokenReaper, []),
     worker(Cog.TemplateCache, []),
     worker(Carrier.CredentialManager, []),
     supervisor(Cog.Relay.RelaySup, []),
     supervisor(Cog.Command.CommandSup, [])] ++ adapter.describe_tree()
  end

  defp get_adapter! do
    adapter = Application.get_env(:cog, :adapter)
    if adapter == nil do
      raise RuntimeError, "Please configure a chat adapter before starting cog."
    else
      adapter_module(adapter)
    end
  end

  defp adapter_module(adapter) when is_binary(adapter), do: String.to_atom("Elixir.#{adapter}")
  defp adapter_module(adapter) when is_atom(adapter), do: adapter
end
