defmodule Cog.Adapters.Test.Recorder do
  use GenServer
  require Logger
  alias Carrier.Messaging.Connection

  def last_message(clear) do
    GenServer.call(__MODULE__, {:last_message, clear})
  end

  def last_response(clear) do
    GenServer.call(__MODULE__, {:last_response, clear})
  end

  def start_link do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(%{}) do
    {:ok, mq_conn} = Connection.connect
    Connection.subscribe(mq_conn, "/bot/adapters/test/+")
    {:ok, %{responses: []}}
  end

  def handle_call({fetch, _clear}, _from, %{responses: []}=state) when fetch in [:last_message, :last_response] do
    {:reply, nil, state}
  end
  def handle_call({fetch, clear}, _from, %{responses: responses}=state) when fetch in [:last_message, :last_response] do
    [h|t] = Enum.reverse(responses)
    state = if clear == true do
      %{state | responses: []}
    else
      %{state | responses: Enum.reverse(t)}
    end
    {:reply, prepare(h, fetch), state}
  end

  def handle_info({:publish, "/bot/adapters/test/send_message", message}, state) do
    case Carrier.CredentialManager.verify_signed_message(message) do
      {true, payload} ->
        {:noreply, %{state | responses: [payload|state.responses]}}
      false ->
        Logger.error("Message signature not verified! #{inspect message}")
        {:noreply, state}
    end
  end
  def handle_info(_, state) do
    {:noreply, state}
  end

  defp prepare(payload, :last_message) do
    payload["response"]
  end
  defp prepare(payload, :last_response) do
    payload
  end

end
