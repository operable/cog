defmodule Cog.Test.Support.ProviderCase do
  alias Cog.Repo
  alias Cog.Bootstrap

  require Logger



  defmacro __using__([provider: provider]) do
    case client_for_provider(provider) do
      nil ->
        raise RuntimeError, message: "Unknown chat provider #{provider}"
      client_mod ->
        quote do

          @moduletag [unquote(provider), :integration]

          require Logger
          use ExUnit.Case, async: false

          import unquote(__MODULE__)
          import Cog.Support.ModelUtilities
          import ExUnit.Assertions

          alias unquote(client_mod), as: ChatClient

          # Only restart the application if we're actually changing the
          # chat provider to something that it's not already configured
          # for.
          setup_all do
            case maybe_replace_chat_provider(unquote(provider)) do
              {:ok, original_provider} ->
                reload_chat_adapter()
                on_exit(fn ->
                  maybe_replace_chat_provider(original_provider)
                  reload_chat_adapter()
                end)
              :no_change ->
                :ok
            end
            :ok
          end

          setup context do
            Ecto.Adapters.SQL.Sandbox.checkout(Repo)
            Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})

            bootstrap
            Cog.Command.PermissionsCache.reset_cache

            :ok
          end
        end
    end
  end

  # If the currently-defined chat provider is different from the one
  # we want to set, then we'll switch out the existing one for the new
  # one, remembering what the original was so we can reset it at the
  # end of the test.
  #
  # If we're already running on the requested chat provider, then
  # we'll make no change to the application configuration and return
  # `:no_change`, indicating that we don't need to restart the
  # application.
  def maybe_replace_chat_provider(string) when is_binary(string),
    do: maybe_replace_chat_provider(String.to_existing_atom(string))
  def maybe_replace_chat_provider(new_provider) do
    config = Application.get_env(:cog, Cog.Chat.Adapter)
    old_provider = Keyword.fetch!(config, :chat)

    if old_provider == new_provider do
      :no_change
    else
      providers = config
      |> Keyword.fetch!(:providers)
      |> Keyword.delete(old_provider)
      |> Keyword.put(new_provider, provider_for(new_provider))

      config = config
      |> Keyword.put(:providers, providers)
      |> Keyword.put(:chat, new_provider)

      Application.put_env(:cog, Cog.Chat.Adapter, config)

      {:ok, old_provider}
    end
  end

  defp provider_for(:slack), do: Cog.Chat.Slack.Provider
  defp provider_for(:hipchat), do: Cog.Chat.HipChat.Provider
  defp provider_for(:test), do: Cog.Chat.Test.Provider
  defp provider_for(other),
    do: raise "I don't know what implements the #{other} provider yet!"

  def reload_chat_adapter() do
    case :erlang.whereis(Cog.Chat.Adapter) do
      :undefined ->
        Logger.error("Can't find Cog.Chat.Adapter process!")
        :erlang.halt(4)
      pid ->
        :erlang.exit(pid, :kill)
    end
  end

  def bootstrap do
    without_logger(fn ->
      Bootstrap.bootstrap
    end)
  end

  def without_logger(fun) do
    Logger.disable(self)
    fun.()
    Logger.enable(self)
  end

  defp client_for_provider(:slack), do: Cog.Test.Support.SlackClient
  defp client_for_provider(:hipchat), do: Cog.Test.Support.HipChatClient
  defp client_for_provider(_), do: nil

end
