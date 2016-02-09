defmodule Cog.Command.Pipeline.Initializer do
  require Logger

  defstruct mq_conn: nil, history: %{}, history_token: ""

  use GenServer

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    cp = Application.get_env(:cog, :command_prefix)
    {:ok, conn} = Carrier.Messaging.Connection.connect()
    Carrier.Messaging.Connection.subscribe(conn, "/bot/commands")
    Logger.info("Ready.")
    {:ok, %__MODULE__{mq_conn: conn, history_token: "#{cp}#{cp}"}}
  end

  def handle_info({:publish, "/bot/commands", message}, state) do
    case Carrier.CredentialManager.verify_signed_message(message) do
      {true, payload} ->
        case check_history(payload, state) do
          {true, payload, state} ->
            {:ok, _} = Cog.Command.Pipeline.ExecutorSup.run(payload)
            {:noreply, state}
          {false, _, state} ->
            {:noreply, state}
        end
      false ->
        Logger.error("Message signature not verified! #{inspect message}")
        {:noreply, state}
    end
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

  defp check_history(payload, state) when is_map(payload) do
    uid = get_in(payload, ["sender", "id"])
    text = String.strip(payload["text"])
    if text == state.history_token do
      retrieve_last(uid, payload, state)
    else
      {true, payload, put_in_history(uid, text, state)}
    end
  end

  defp put_in_history(uid, text, %__MODULE__{history: history}=state) do
    %{state | history: Map.put(history, uid, text)}
  end

  defp retrieve_last(uid, payload, %__MODULE__{history: history}=state) do
    case Map.get(history, uid) do
      nil ->
        response = %{response: "No history available.",
                     room: payload["room"],
                     adapter: payload["adapter"]}
        Carrier.Messaging.Connection.publish(state.mq_conn, response, routed_by: payload["reply"])
        {false, Poison.encode!(payload), state}
      previous ->
        {true, Poison.encode!(Map.put(payload, "text", previous)), state}
    end
  end

end
