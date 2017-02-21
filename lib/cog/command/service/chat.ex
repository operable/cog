defmodule Cog.Command.Service.Chat do
  require Logger
  
  alias Cog.Chat.Adapter

  def send_message(destination, message) do
    {:ok, provider} = Cog.Util.Misc.chat_provider_module

    case build_target(provider, destination) do
      {:ok, target} ->
        Cog.Chat.Adapter.send("slack", target, message, %{originating_room_id: target.id})
      {:error, reason} ->
        Logger.debug("Invalid message destination: #{inspect destination}")
        {:error, reason}
    end
  end

  defp build_target(provider, "@" <> handle) do
    case Adapter.lookup_user(provider, handle) do
      {:ok, %{id: user_id}} -> 
        {:ok, %{provider: provider, id: user_id, name: handle, is_dm: true}}
      _ ->
        {:error, :unknown_handle}
    end
  end
  defp build_target(provider, "#" <> room) do
    case Adapter.lookup_room(provider, name: "##{room}") do
      {:ok, %{id: room_id}} -> 
        {:ok, %{provider: provider, id: room_id, name: room, is_dm: false}}
      _ ->
        {:error, :unknown_room}
    end    
  end
  defp build_target(_provider, _destination) do
    {:error, :invalid_destination}
  end

end
