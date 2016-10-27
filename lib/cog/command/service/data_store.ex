defmodule Cog.Command.Service.DataStore do
  @moduledoc """
  Stores an arbitrary data structure for a given key. The only requirement is
  that the data structure must be able to be encoded as JSON.

  Keys may be fetched, replaced, and deleted.

  The JSON data is stored on the filesystem of the Cog host. See the
  Cog.NestedFile module for more details.
  """

  use GenServer

  alias Cog.NestedFile

  defstruct [:base_path]

  @doc """
  Starts the #{inspect __MODULE__} service. Accepts a path to use for the
  base directory to store content under.
  """
  def start_link(base_path),
    do: GenServer.start_link(__MODULE__, base_path, name: __MODULE__)

  @doc """
  Fetches the given key. Returns `{:ok, value}` if the key exists or `{:error,
  :unknown_key}` if it doesn't exist.
  """
  def fetch(namespace, key),
    do: GenServer.call(__MODULE__, {:fetch, namespace, key})

  @doc """
  Replaces or sets the given key with the value. Returns `{:ok, value}`.
  """
  def replace(namespace, key, value),
    do: GenServer.call(__MODULE__, {:replace, namespace, key, value})

  @doc """
  Deletes the given key. Returns `{:ok, key}` when successfully
  deleted or `{:error, :unknown_key}` if it doesn't exist.
  """
  def delete(namespace, key),
    do: GenServer.call(__MODULE__, {:delete, namespace, key})

  def init(nil),
    do: {:stop, "Unable to start #{__MODULE__}: Data path not configured"}
  def init(base_path) do
    state = %__MODULE__{base_path: base_path}
    {:ok, state}
  end

  def handle_call({:fetch, namespace, key}, _from, state) do
    case NestedFile.fetch([state.base_path] ++ namespace, key, "json") do
      {:ok, content} ->
        data = Poison.decode!(content)
        {:reply, {:ok, data}, state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:replace, namespace, key, value}, _from, state) do
    content = Poison.encode!(value)

    case NestedFile.replace([state.base_path] ++ namespace, key, content, "json") do
      {:ok, ^content} ->
        {:reply, {:ok, value}, state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:delete, namespace, key}, _from, state) do
    case NestedFile.delete([state.base_path] ++ namespace, key, "json") do
      :ok ->
        {:reply, {:ok, key}, state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
end
