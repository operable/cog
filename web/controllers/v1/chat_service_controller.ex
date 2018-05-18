defmodule Cog.V1.ChatServiceController do
  use Cog.Web, :controller
  require Logger

  plug Cog.Plug.ServiceAuthentication

  alias Cog.Command.Service.Chat

  def send_message(conn, %{"destination" => destination, "message" => message}) do
    case Chat.send_message(destination, message) do
      {:error, reason} when reason == :unknown_handle or reason == :unknown_room or reason == :invalid_destination ->
        conn
        |> put_status(:not_found)
        |> json(%{"error" => destination_error(destination, reason)})
      _ ->
        conn
        |> put_status(:ok)
        |> json(%{"status": "sent"})
    end
  end

  defp destination_error(destination, :unknown_handle) do
    "Unable to find chat user for #{destination}"
  end
  defp destination_error(destination, :unknown_room) do
    "Unable to find chat room for #{destination}"
  end
  defp destination_error(destination, _reason) do
    "Invalid chat destination URI #{destination}"
  end

end
