use Mix.Config

config :emqttd, :listeners,
  [{mqtt_type, mqtt_port,
    [acceptors: 4,
     max_clients: 64,
     access: [allow: :all],
     ssl: [certfile: cert,
           keyfile: key],
     sockopts: [backlog: 2,
                ip: mqtt_addr,
                delay_send: false]]}]
