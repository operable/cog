use Mix.Config

config :emqttd, :listeners,
  [{mqtt_type, mqtt_port,
    [acceptors: 16,
     max_clients: 64,
     access: [allow: :all],
     ssl: [certfile: cert,
           keyfile: key],
     sockopts: [backlog: 8,
                ip: mqtt_addr,
                recbuf: 4096,
                sndbuf: 4096,
                buffer: 4096]]}]
