defmodule Cog.Chat.Http.Connector do
  @moduledoc """
  Mediates interactions between HTTP requests and pipeline executions
  """
  alias Cog.Chat.Http.Provider

  use GenServer
  require Logger

  def start_link,
    do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  def submit_request(requestor, id, initial_context, pipeline, timeout) do
    try do
      GenServer.call(__MODULE__,
                     {:submit_request, requestor, id, initial_context, pipeline},
                     timeout)
    catch
      :exit, {:timeout,_} ->
        {:error, :timeout}
    end
  end

  def finish_request(room, response),
    do: GenServer.call(__MODULE__, {:finish_request, room, response})

  ########################################################################

  def init([]),
    do: {:ok, %{}}

  # TODO: pass timeout in order to queue up clearing the data from the map?
  def handle_call({:submit_request, requestor, id, initial_context, pipeline}, from, state) do
    GenServer.cast(Provider, {:pipeline, requestor, id, initial_context, pipeline})
    {:noreply, Map.put(state, id, from)}
  end
  def handle_call({:finish_request, room_id, response}, _from, state) do
    case Map.fetch(state, room_id) do
      {:ok, requestor} ->
        GenServer.reply(requestor, response)
        {:reply, :ok, Map.delete(state, room_id)}
      :error ->
        Logger.warn("Handling a finish_request call for unknown request `#{room_id}`")
        {:reply, :error, state}
    end
  end

end
