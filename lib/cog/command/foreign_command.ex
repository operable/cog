defmodule Cog.Command.ForeignCommand do
  use GenServer
  alias Cog.Command.ForeignCommand.Helper
  alias Cog.Command.Request
  alias Spanner.Command.Response
  alias Cog.Models.Bundle
  alias Carrier.Messaging.Connection
  require Logger

  defstruct [:mq_conn, :bundle, :name, :executable, ports: %{}]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init([bundle: bundle, name: name, executable: executable]) do
    {:ok, conn} = Connection.connect

    topic = "/bot/commands/#{bundle}/#{name}"
    Logger.debug("Command subscribing to #{topic(bundle, name)}")
    Connection.subscribe(conn, topic)

    {:ok, %__MODULE__{mq_conn: conn, bundle: bundle, name: name, executable: executable}}
  end

  def handle_info({:publish, "/bot/commands/" <> _, message}, state) do
    case Carrier.CredentialManager.verify_signed_message(message) do
      {true, payload} ->
        req = Request.decode!(payload)

        executable = executable_path(state.bundle, state.executable)

        case Helper.execute(executable, req) do
          {:ok, port} ->
            port_entry = %{req: req, collectable: Collectable.into("")}

            ports = Map.put(state.ports, port, port_entry)
            {:noreply, %{state | ports: ports}}
          {:error, error} ->
            Logger.error("Received an error when opening a port to #{executable}: #{inspect error}")
            response = "Oops. We received an error when trying to run that command"

            resp = Response.encode!(%Response{status: :ok, body: [response]})
            Connection.publish(state.mq_conn, resp, routed_by: req.reply_to)

            {:noreply, state}
        end
      false ->
        Logger.error("Message signature not verified! #{inspect message}")
        {:noreply, state}
    end
  end
  def handle_info({port, {:data, data}}, state) do
    ports = update_in(state.ports, [port, :collectable], fn {acc, func} ->
      {func.(acc, {:cont, to_string(data)}), func}
    end)

    {:noreply, %{state | ports: ports}}
  end
  def handle_info({port, {:exit_status, status}}, state) do
    port_entry = Map.fetch!(state.ports, port)
    {acc, func} = port_entry.collectable
    output = func.(acc, :done)

    response = case {output, status} do
      {output, 0} ->
        output
      {output, status} ->
        Logger.error("Recieved the following output before an exit status of #{status}:\n #{output}")
        "Oops. The command returned a non-zero exit status."
    end

    resp = Response.encode!(%Response{status: :ok, body: [response]})
    Connection.publish(state.mq_conn, resp, routed_by: port_entry.req.reply_to)

    ports = Map.delete(state.ports, port)
    {:noreply, %{state | ports: ports}}
  end
  def handle_info(_, state) do
    {:noreply, state}
  end

  defp executable_path(bundle_name, executable) do
    Path.join([Bundle.bundle_root!, bundle_name, executable])
  end

  defp topic(bundle, name) do
    "/bot/commands/#{bundle}/#{name}"
  end
end
