use Mix.Config

config :logger, :console,
  level: :info

config :cog, Cog.Repo,
  adapter: Ecto.Adapters.Postgres,
  pool_size: 20

config :emqttd, :listeners,
  [{:mqtt, 1883, [acceptors: 16,
                  max_clients: 64,
                  access: [allow: :all],
                  sockopts: [backlog: 8,
                             ip: "127.0.0.1",
                             recbuf: 4096,
                             sndbuf: 4096,
                             buffer: 4096]]}]

config :cog, Cog.Endpoint,
  http: [port: {:system, "PORT"}],
  url: [host: "example.com", port: 80],
  cache_static_manifest: "priv/static/manifest.json"

config :cog, Cog.Endpoint,
  secret_key_base: "NhUaByeWuGHgE+lJsuOEKSnv88BLlH2xQcPRG7u9HazAYmenEGjZEyiywSwbKoRc"
