defmodule Cog.AdapterCase do
  alias ExUnit.CaptureLog
  alias Cog.Repo
  alias Cog.Bootstrap

  require Logger



  @vcr_adapter ExVCR.Adapter.IBrowse

  defmacro __using__([adapter: adapter]) do

    adapter_helper = Module.concat([Cog, Adapters, String.capitalize(adapter), Helpers])

    quote do
      require Logger
      use ExUnit.Case, async: false

      import unquote(adapter_helper)
      import unquote(__MODULE__)
      import Cog.Support.ModelUtilities
      import ExUnit.Assertions
      import Cog.AdapterAssertions

      # Only restart the application if we're actually changing the
      # chat provider to something that it's not already configured
      # for.
      setup_all do
        case maybe_replace_chat_provider(unquote(adapter)) do
          {:ok, original_provider} ->
            restart_application
            on_exit(fn ->
              maybe_replace_chat_provider(original_provider)
              restart_application
            end)
          :no_change ->
            :ok
        end
        :ok
      end

      setup context do
        # recorder = start_recorder(unquote(adapter), context)

        Ecto.Adapters.SQL.Sandbox.checkout(Repo)
        Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})

        bootstrap
        Cog.Command.PermissionsCache.reset_cache

        # on_exit(fn ->
        #   stop_recorder(recorder)
        # end)

        :ok
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
      # TODO: This is "old" configuration that will eventually be replaced
      Application.put_env(:cog, :adapter, new_provider)

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

  defp provider_for(:test),  do: Cog.Chat.TestProvider
  defp provider_for(:slack), do: Cog.Chat.SlackProvider
  defp provider_for(other),
    do: raise "I don't know what implements the #{other} provider yet!"

  def restart_application do
    CaptureLog.capture_log(fn ->
      :ok = Application.stop(:cog)
      :ok = Application.start(:cog)
    end)
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

  # The following recorder functions were adapted from ExVCR's `use_cassette`
  # function which could not be easily used here.
  def start_recorder("test", _context), do: nil
  def start_recorder(_adapter, context) do
    fixture = ExVCR.Mock.normalize_fixture("#{context.case}.#{context.test}")
    recorder = ExVCR.Recorder.start(fixture: fixture, adapter: @vcr_adapter, match_requests_on: [:query, :request_body])

    ExVCR.Mock.mock_methods(recorder, @vcr_adapter)

    recorder
  end

  def stop_recorder(nil), do: nil
  def stop_recorder(recorder) do
    try do
      :meck.unload(@vcr_adapter.module_name)
    after
      ExVCR.Recorder.save(recorder)
    end
  end
end
