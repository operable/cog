defmodule Cog.Adapters.IRC.Connection do
  use GenServer
  alias Cog.Adapters.IRC

  defstruct [:client, :host, :port, :nick, :channel]

  def send_message(room, message) do
    GenServer.call(__MODULE__, {:send_message, room, message})
  end

  def start_link(client, host, port, nick, channel) do
    GenServer.start_link(__MODULE__, [client, host, port, nick, channel], name: __MODULE__)
  end

  def init([client, host, port, nick, channel]) do
    ExIrc.Client.add_handler(client, self)
    ExIrc.Client.connect!(client, host, port)
    {:ok, %__MODULE__{client: client, host: host, port: port, nick: nick, channel: channel}}
  end

  def handle_call({:send_message, room, message}, _from, %{client: client} = state) do
    ExIrc.Client.msg(client, :privmsg, room["name"], message)
    {:reply, :ok, state}
  end

  def handle_info({:connected, _, _}, %{client: client, nick: nick} = state) do
    ExIrc.Client.logon(client, nil, nick, nick, nick)
    {:noreply, state}
  end

  def handle_info(:logged_in, %{client: client, channel: channel} = state) do
    ExIrc.Client.join(client, channel)
    {:noreply, state}
  end

  def handle_info({:received, message, nick, channel}, state) do
    with {true, message} <- mentioned?(message, state.nick) do
      sender = %{handle: nick, id: nick}
      room = %{name: channel, id: channel}
      IRC.receive_message(sender, room, message)
    end

    {:noreply, state}
  end

  def handle_info(message, state) do
    IO.inspect(message)
    {:noreply, state}
  end

  def terminate(_reason, %{client: client}) do
    ExIrc.Client.stop!(client)
    :ok
  end

  defp mentioned?(message, nick) do
    case String.starts_with?(message, nick) do
      true ->
        ["", message] = String.split(message, nick)
        message = Regex.replace(~r/^:\s*/, message, "")
        {true, message}
      false ->
        false
    end
  end
end
