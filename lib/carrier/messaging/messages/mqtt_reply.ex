defmodule Carrier.Messaging.Messages.MqttReply do

  use Conduit

  field :flag, :string, [enum: ["ok", "error"], required: true]
  field :result, :array, required: false

end
