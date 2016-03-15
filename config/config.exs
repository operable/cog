use Mix.Config
use Cog.Config.Helpers

# ========================================================================
# Chat Adapters

config :cog,
  adapter: System.get_env("COG_ADAPTER") || "slack"

config :cog, :enable_spoken_commands, ensure_boolean(System.get_env("ENABLE_SPOKEN_COMMANDS")) || true

config :cog, :message_bus,
  host: System.get_env("COG_MQTT_HOST") || "127.0.0.1",
  port: ensure_integer(System.get_env("COG_MQTT_PORT")) || 1883

# Uncomment the next three lines and edit ssl_cert and ssl_key
# to point to your SSL certificate and key files.
# config :cog, :message_bus,
#  ssl_cert: "priv/ssl/cert.pem",
#  ssl_key: "priv/ssl/key.pem"

config :cog, Cog.Adapters.Slack,
  api_token: System.get_env("SLACK_API_TOKEN"),
  api_cache_ttl: System.get_env("SLACK_API_CACHE_TTL") || 900

config :cog, Cog.Adapters.HipChat,
  xmpp_jid: System.get_env("HIPCHAT_XMPP_JID"),
  xmpp_password: System.get_env("HIPCHAT_XMPP_PASSWORD"),
  xmpp_nickname: System.get_env("HIPCHAT_XMPP_NICKNAME") || "Cog",
  xmpp_server: System.get_env("HIPCHAT_XMPP_SERVER"),
  xmpp_port: System.get_env("HIPCHAT_XMPP_PORT") || 5222,
  xmpp_resource: "bot",
  xmpp_rooms: System.get_env("HIPCHAT_XMPP_ROOMS"),
  api_token: System.get_env("HIPCHAT_API_TOKEN"),
  mention_name: System.get_env("HIPCHAT_MENTION_NAME")

config :cog, Cog.Adapters.IRC,
  host: System.get_env("IRC_HOST"),
  port: System.get_env("IRC_PORT"),
  channel: System.get_env("IRC_CHANNEL"),
  nick: System.get_env("IRC_NICK"),
  user: System.get_env("IRC_USER"),
  name: System.get_env("IRC_NAME"),
  password: System.get_env("IRC_PASSWORD"),
  use_ssl: System.get_env("IRC_USE_SSL") || true

# ========================================================================
# Commands, Bundles, and Services

config :cog, :command_prefix, "!"

config :cog, Cog.Bundle.BundleSup,
  bundle_root: Path.join([File.cwd!, "bundles"])

# Set these to zero (0) to disable caching
config :cog, :command_cache_ttl, {60, :sec}
config :cog, :command_rule_ttl, {10, :sec}
config :cog, :template_cache_ttl, {60, :sec}
config :cog, :user_perms_ttl, {10, :sec}

config :cog, :emqttc,
  log_level: :info

# How many levels deep do we expand aliases, '0' disables aliases
config :cog, :max_alias_expansion, 5

# ========================================================================
# Logging

log_opts = [metadata: [:module, :line], format: {Adz, :text}]

config :logger,
  backends: [:console, {LoggerFileBackend, :cog_log}],
  console: log_opts,
  cog_log: log_opts ++ [path: data_dir("cog.log")]

config :lager, :error_logger_redirect, false
config :lager, :error_logger_whitelist, [Logger.ErrorHandler]
config :lager, :crash_log, false
config :lager, :handlers, [{LagerLogger, [level: :debug]}]

config :probe, log_directory: data_dir("audit_logs")

# ========================================================================
# Database Setup

config :cog, Cog.Repo,
  adapter: Ecto.Adapters.Postgres,
  url: (case System.get_env("DATABASE_URL") do
          nil -> "ecto://#{System.get_env("USER")}@localhost/cog_#{Mix.env}"
          url -> url
        end),
  pool_size: ensure_integer(System.get_env("COG_DB_POOL_SIZE")) || 10,
  pool_timeout: ensure_integer(System.get_env("COG_DB_POOL_TIMEOUT")) || 15000,
  timeout: ensure_integer(System.get_env("COG_DB_TIMEOUT")) || 15000,
  parameters: [timezone: 'UTC']

# ========================================================================

config :carrier, :credentials_dir, data_dir("carrier_creds")

config :carrier, Carrier.Messaging.Connection,
  host: System.get_env("COG_MQTT_HOST") || "127.0.0.1",
  port: ensure_integer(System.get_env("COG_MQTT_PORT")) || 1883,
  log_level: :info

# ========================================================================
# Web Endpoints

config :cog, Cog.Endpoint,
  http: [port: System.get_env("COG_WEB_PORT") || 4000],
  root: Path.dirname(__DIR__),
  debug_errors: false,
  cache_static_lookup: false,
  check_origin: true,
  render_errors: [accepts: ~w(json)],
  pubsub: [name: Carrier.Messaging.Connection,
           adapter: Phoenix.PubSub.PG2],
  secret_key_base: System.get_env("COG_COOKIE_SECRET")

config :cog, :token_lifetime, {1, :week}
config :cog, :token_reap_period, {1, :day}

import_config "#{Mix.env}.exs"
