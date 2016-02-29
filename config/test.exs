use Mix.Config

config :logger, :console,
  level: :info

config :cog,
  adapter: "null"

config :cog, Cog.Repo,
  pool: Ecto.Adapters.SQL.Sandbox

config :cog,
  :template_cache_ttl, {1, :sec}

config :cog, Cog.Endpoint,
  http: [port: 4001],
  catch_errors: true,
  cache_static_lookup: false,
  server: false,
  secret_key_base: "test-secret"

# 4-round hashing for test/dev only
config :comeonin,
  bcrypt_log_rounds: 4

config :cog, Cog.Bundle.BundleSup,
  bundle_root: Path.join([File.cwd!, "test", "support", "bundles"])

config :ex_unit,
  capture_log: true,
  timeout: 180000 # 3 minutes
  # The increased timeout allows integration tests enough time to properly
  # timeout on their own after 2 minutes.
