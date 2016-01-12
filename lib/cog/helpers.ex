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

  # This allows us to convert to negative numbers instead of the "-" being mistaken for a flag or a string
  def get_number(num) do
    case is_number(num) do
      true -> num
      false -> convert_num(num)
    end
  end

  def convert_num(num) do
    case Float.parse(num) do
      {val, _} -> val
      :error -> "#{num} is not a number"
    end
  end
end
