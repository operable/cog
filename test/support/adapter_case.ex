defmodule Cog.AdapterCase do
  alias ExUnit.CaptureLog
  alias Cog.Repo
  alias Cog.Bootstrap

  defmacro __using__([adapter: adapter]) do
    {:ok, adapter_module} = Cog.adapter_module(String.downcase(adapter))
    adapter_helper = Module.concat([adapter_module, "Helpers"])

    quote do
      use ExUnit.Case
      import unquote(adapter_helper)
      import unquote(__MODULE__)
      import Cog.Support.ModelUtilities
      import ExUnit.Assertions

      setup_all do
        adapter = replace_adapter(unquote(adapter))
        Ecto.Adapters.SQL.begin_test_transaction(Repo)

        on_exit(fn ->
          Ecto.Adapters.SQL.rollback_test_transaction(Repo)
          reset_adapter(adapter)
        end)

        :ok
      end

      setup do
        Ecto.Adapters.SQL.restart_test_transaction(Repo, [])
        bootstrap
        Cog.Command.UserPermissionsCache.reset_cache
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
    restart_application
    adapter
  end

  def reset_adapter(adapter) do
    Application.put_env(:cog, :adapter, adapter)
    restart_application
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
end
