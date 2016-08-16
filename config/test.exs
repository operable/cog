use Mix.Config

config :logger, :console,
  level: :info

config :lager, :handlers,
  [{LagerLogger, [level: :error]}]

config :cog, Cog.Chat.Adapter,
  providers: [test: Cog.Chat.TestProvider],
  chat: :test

config :cog, Cog.Chat.TestProvider,
  verbose: true

config :cog, Cog.Repo,
  pool: Ecto.Adapters.SQL.Sandbox

config :cog,
  :template_cache_ttl, {1, :sec}

config :cog, Cog.Endpoint,
  http: [port: 4001],
  catch_errors: true,
  cache_static_lookup: false,
  secret_key_base: "test-secret"

config :cog, Cog.ServiceEndpoint,
  server: true

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

# ========================================================================
# Emails

config :cog, Cog.Mailer, adapter: Bamboo.TestAdapter
config :cog, :email_from, "test@example.com"
config :cog, :password_reset_base_url, "http://cog.localhost/reset-password"
