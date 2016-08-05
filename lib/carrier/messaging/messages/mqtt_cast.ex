defmodule Carrier.Messaging.Messages.MqttCast do

  use Conduit

  field :endpoint, :string, required: true
  field :payload, :map, required: true

end
