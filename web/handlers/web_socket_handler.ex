defmodule Cog.Handlers.WebSocketHandler do
  @behaviour :cowboy_websocket_handler

  def init({:tcp, :http}, _req, _opts) do
    {:upgrade, :protocol, :cowboy_websocket}
  end

  def websocket_init(_transport_name, req, _opts) do
    :gproc.reg({:p, :l, __MODULE__})
    {:ok, req, %{}}
  end

  def websocket_handle(data, req, state) do
    pids = :gproc.lookup_pids({:p, :l, __MODULE__})

    for pid <- pids, pid != self do
      send(pid, data)
    end

    {:ok, req, state}
  end

  def websocket_info(info, req, state) do
    {:reply, info, req, state}
  end

  def websocket_terminate(_reason, _req, _state) do
    :ok
  end
end
