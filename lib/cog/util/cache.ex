defmodule Cog.Util.Cache do

  alias Cog.Util.CacheImpl

  defstruct [:pid, :name]

  @behaviour Access

  def fetch(%__MODULE__{name: name}, key) do
    case CacheImpl.lookup(name, key) do
      {:ok, nil} ->
        :error
      {:ok, value} ->
        {:ok, value}
      _ ->
        :error
    end
  end

  def get(%__MODULE__{name: name}, key, default \\ nil) do
    case CacheImpl.lookup(name, key) do
      {:ok, nil} ->
        default
      {:ok, value} ->
        value
    end
  end

  def put(%__MODULE__{pid: pid}=cache, key, value) do
    case CacheImpl.store(pid, key, value) do
      :ok ->
        {:ok, cache}
      error ->
        error
    end
  end

  def get_and_update(%__MODULE__{pid: pid}=cache, key, fun) do
    value = __MODULE__.get(cache, key)
    case fun.(value) do
      :pop ->
        CacheImpl.delete(pid, key)
        value
      {old_value, new_value} ->
        CacheImpl.store(pid, key, new_value)
        {old_value, cache}
    end
  end

  def pop(%__MODULE__{pid: pid}=cache, key) do
    case __MODULE__.get(cache, key) do
      nil ->
        {nil, cache}
      value ->
        CacheImpl.delete(pid, key)
        {value, cache}
    end
  end

  def close(%__MODULE__{pid: pid}) do
    CacheImpl.close(pid)
  end

end
