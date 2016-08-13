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

      Logger.warn(">>>>>>> Module = #{inspect __MODULE__, pretty: true}")


      import unquote(adapter_helper)
      import unquote(__MODULE__)
      import Cog.Support.ModelUtilities
      import ExUnit.Assertions
      import Cog.AdapterAssertions

      setup_all do
        adapter = replace_adapter(unquote(adapter))

        on_exit(fn ->
          reset_adapter(adapter)
        end)

        :ok
      end

      setup context do
        recorder = start_recorder(unquote(adapter), context)

        Ecto.Adapters.SQL.Sandbox.checkout(Repo)
        Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
        bootstrap
        Cog.Command.PermissionsCache.reset_cache

        on_exit(fn ->
          stop_recorder(recorder)
        end)

        :ok
      end

    end
  end

  # If we are using the test adapter, we do nothing
  def replace_adapter("test"),
    do: Application.get_env(:cog, :adapter)
  def replace_adapter(new_adapter) do
    adapter = Application.get_env(:cog, :adapter)
    Application.put_env(:cog, :adapter, new_adapter)

    set_chat_adapter(new_adapter)

    restart_application
    adapter
  end

  def reset_adapter(adapter) do
    Application.put_env(:cog, :adapter, adapter)
    set_chat_adapter(adapter)
    restart_application
  end

  defp set_chat_adapter(adapter) do
    config = :cog
    |> Application.get_env(Cog.Chat.Adapter)
    |> Keyword.put(:chat, String.to_atom(adapter))

    Logger.warn(">>>>>>> config = #{inspect config, pretty: true}")

    Application.put_env(:cog, Cog.Chat.Adapter, config)
  end

  def restart_application do
    CaptureLog.capture_log(fn ->
      Application.stop(:cog)
      Application.start(:cog)
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
