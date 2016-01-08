defmodule Cog.Helpers do
  def ensure_integer(ttl) when is_binary(ttl), do: String.to_integer(ttl)
  def ensure_integer(ttl) when is_integer(ttl), do: ttl

  # TODO: Use Macro.underscore/1 once available
  def module_key(module) do
    module
    |> Module.split
    |> List.last
    |> String.downcase
  end

  def send_reply(reply_string, payload, conn) do
    generate_reply(reply_string, payload)
    |> publish_reply(payload["reply"], conn)
  end

  def generate_reply(reply, payload) do
    %{room: payload["room"], text: reply}
  end

  def publish_reply(reply, routed_by, mq_conn) do
    Carrier.Messaging.Connection.publish(mq_conn, reply, routed_by: routed_by)
  end
end
