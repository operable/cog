use Mix.Config
import Cog.Config.Helpers

config :logger, :console,
  level: :debug

config :lager, :handlers,
  [{LagerLogger, [level: :error]}]

config :cog, :enable_spoken_commands, ensure_boolean(System.get_env("ENABLE_SPOKEN_COMMANDS")) || false

config :cog,
  :template_cache_ttl, {1, :sec}

config :cog, Cog.Endpoint,
  debug_errors: true,
  code_reloader: true,
  cache_static_lookup: false,
  check_origin: false,
  render_errors: [view: Cog.ErrorView, accepts: ~w(json)]

config :cog, Cog.Endpoint,
  live_reload: [
    patterns: [
      ~r{lib/cog/models/.*(ex)$},
      ~r{web/.*(ex)$}
    ]
  ]

config :comeonin,
  bcrypt_log_rounds: 14

# Configure Phoenix Generators
config :phoenix, :generators,
  migration: true,
  binary_id: false
