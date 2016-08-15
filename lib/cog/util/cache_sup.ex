defmodule Cog.Util.CacheSup do
  use Supervisor

  alias Cog.Config

  def start_link,
    do: Supervisor.start_link(__MODULE__, [], name: __MODULE__)

  def init(_) do
    children = [worker(Cog.Util.CacheImpl, [], restart: :transient, shutdown: :brutal_kill)]
    supervise(children, strategy: :simple_one_for_one)
  end

  def create_cache(name, ttl) when is_atom(name) do
    ttl = Config.convert(ttl, :sec)
    cache_args = [name: name, ttl: ttl]
    case Supervisor.start_child(__MODULE__, [cache_args]) do
      {:ok, pid} ->
        {:ok, %Cog.Util.Cache{pid: pid, name: name}}
      error ->
        error
    end
  end

  def get_or_create_cache(name, ttl) when is_atom(name) do
    case :erlang.whereis(name) do
      pid when is_pid(pid) ->
        {:ok, %Cog.Util.Cache{pid: pid, name: name}}
      :undefined ->
        case create_cache(name, ttl) do
          {:ok, cache} ->
            {:ok, cache}
          {:error, {:already_started, pid}} ->
            {:ok, %Cog.Util.Cache{pid: pid, name: name}}
          error ->
            error
        end
    end
  end

end
