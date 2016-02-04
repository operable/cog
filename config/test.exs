use Mix.Config

config :logger, :console,
  level: :info

config :cog,
  adapter: Cog.Adapters.Null

config :cog, Cog.Repo,
  pool: Ecto.Adapters.SQL.Sandbox

config :carrier, Carrier.Messaging.Connection,
  host: "127.0.0.1",
  port: 1884,
  log_level: :info

config :cog,
  :template_cache_ttl, {1, :sec}

config :emqttd, :listeners,
  [{:mqtt, 1884, [acceptors: 16,
                  max_clients: 64,
                  access: [allow: :all],
                  sockopts: [backlog: 8,
                             ip: "127.0.0.1",
                             recbuf: 4096,
                             sndbuf: 4096,
                             buffer: 4096]]}]

config :cog, Cog.Endpoint,
  http: [port: 4001],
  catch_errors: true,
  cache_static_lookup: false,
  server: false,
  secret_key_base: "test-secret"

# 4-round hashing for test/dev only
config :comeonin,
  bcrypt_log_rounds: 4

config :cog, :ec2_service,
  aws_access_key_id: "not-used",
  aws_secret_access_key: "not-used"

config :cog, Cog.Bundle.BundleSup,
  bundle_root: Path.join([File.cwd!, "test", "support", "bundles"])

config :ex_unit,
  capture_log: true,
  timeout: 180000 # 3 minutes
  # The increased timeout allows integration tests enough time to properly
  # timeout on their own after 2 minutes.
