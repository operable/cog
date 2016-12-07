use Mix.Config

config :lager, :handlers,
  [{LagerLogger, [level: :error]}]

config :cog, Cog.Chat.Adapter,
  providers: [test: Cog.Chat.Test.Provider,
              http: Cog.Chat.Http.Provider],
  cache_ttl: {1, :sec},
  chat: :test

config :cog, Cog.Chat.Test.Provider,
  verbose: true

config :cog, Cog.Repo,
  pool: Ecto.Adapters.SQL.Sandbox,
  # Bumping timeout up because we might sleep for >60s to get around
  # Slack API throttling
  ownership_timeout: 120_000

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
