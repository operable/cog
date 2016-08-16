use Mix.Config

config :logger, :console,
  level: :info

config :lager, :handlers,
  [{LagerLogger, [level: :error]}]

config :cog,
  adapter: System.get_env("COG_ADAPTER")

config :cog, Carrier.Messaging.Connection,
  host: "127.0.0.1",
  port: 1883

config :emqttd, :listeners,
  [{:mqtt, 1883, [acceptors: 16,
                  max_clients: 64,
                  access: [allow: :all],
                  sockopts: [backlog: 8,
                             ip: "127.0.0.1",
                             recbuf: 4096,
                             sndbuf: 4096,
                             buffer: 4096]]}]

config :cog, Cog.Repo,
  adapter: Ecto.Adapters.Postgres,
  pool_size: 10

config :cog, Cog.Endpoint,
  http: [port: System.get_env("COG_WEB_PORT") || 4000],
  debug_errors: false,
  cache_static_lookup: true,
  check_origin: true,
  secret_key_base: System.get_env("COG_COOKIE_SECRET")

config :comeonin,
  bcrypt_log_rounds: 14
