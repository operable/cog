defmodule Carrier.Messaging.Messages.MqttCall do

  use Conduit

  field :sender, :string, required: true
  field :endpoint, :string, required: true
  field :payload, :map, required: true

end
