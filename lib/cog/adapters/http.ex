defmodule Cog.Adapters.Http do
  use Cog.Adapter

  require Logger

  def send_message(room, response),
    do: Cog.Adapters.Http.AdapterBridge.finish_request(room, response)

  def lookup_room(_room),
    do: {:error, :not_found}

  def lookup_direct_room(_opts),
    do: raise "Not Implemented"

  def room_writeable?(_),
    do: false

  def lookup_user(_),
    do: nil

  def mention_name(name),
    do: name

  def name,
    do: "http"

  def display_name,
    do: "HTTP"

  def chat_adapter?,
    do: false

end
