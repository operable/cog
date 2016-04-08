defmodule Cog.Adapters.Http.AdapterBridge do
  @moduledoc """
  Mediates interactions between HTTP requests and pipeline executions
  """

  use GenServer
  use Adz

  def start_link,
    do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  def submit_request(cog_user_name, id, initial_context, pipeline, timeout) do
    try do
      GenServer.call(__MODULE__,
                     {:submit_request, cog_user_name, id, initial_context, pipeline},
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
    room = %{"id" => id}
    Cog.Adapters.Http.receive_message(requestor, room, pipeline, id, initial_context)
    {:noreply, Map.put(state, id, from)}
  end
  def handle_call({:finish_request, room, response}, _from, state) do
    id = Map.get(room, "id")
    case Map.fetch(state, id) do
      {:ok, requestor} ->
        GenServer.reply(requestor, response)
        {:reply, :ok, Map.delete(state, id)}
      :error ->
        Logger.warn("Handling a finish_request call for unknown request `#{id}`")
        {:reply, :error, state}
    end
  end

end
