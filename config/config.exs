use Mix.Config
import Cog.Config.Helpers

# ========================================================================
# Cog Telemetry - By default, Cog is configured to send an event to the
# Operable telemetry service every time it starts. This event contains a
# unique ID (based on the SHA256 of the UUID for your operable bundle),
# the Cog version number, and the Elixir mix environment (:prod, :dev, etc)
# that Cog is running under.
#
# If you would like to opt-out of sending this data, you can set the
# COG_TELEMETRY environment variable to "false".
# ========================================================================

config :cog, :telemetry, ensure_boolean(System.get_env("COG_TELEMETRY") || true)

# ========================================================================
# Set this to :unenforcing to globally disable all access rules.
# NOTE: This is a global setting.
# ========================================================================

if System.get_env("DISABLE_RULE_ENFORCEMENT") do
  config :cog, :access_rules, :unenforcing
else
  config :cog, :access_rules, :enforcing
end

# ========================================================================
# Embedded Command Bundle Version (for built-in commands)
# NOTE: Do not change this value unless you know what you're doing.
# ========================================================================

config :cog, :embedded_bundle_version, "0.18.1"

# ========================================================================
# Chat Adapters
# ========================================================================

config :cog, Cog.Chat.Http.Provider, []

config :cog, Cog.Chat.Adapter,
  providers: provider_list(),
  chat: enabled_chat_provider()

config :cog, :enable_spoken_commands, ensure_boolean(System.get_env("ENABLE_SPOKEN_COMMANDS")) || true

config :cog, :message_bus,
  host: System.get_env("COG_MQTT_HOST") || "127.0.0.1",
  port: ensure_integer(System.get_env("COG_MQTT_PORT")) || 1883

# Uncomment the next three lines and edit ssl_cert and ssl_key
# to point to your SSL certificate and key files.
# config :cog, :message_bus,
#  ssl_cert: "public.crt",
#  ssl_key: "secret.key"

# Chat provider APIs may be slow to respond to requests in some cases
# so we set a generous timeout.
config :httpotion, :default_timeout, 30000

# ========================================================================
# Commands, Bundles, and Services

config :cog, :command_prefix, System.get_env("COG_COMMAND_PREFIX") || "!"
config :cog, :previous_command_token, System.get_env("COG_PREVIOUS_COMMAND_TOKEN") || "!!"

config :cog, Cog.Bundle.BundleSup,
  bundle_root: Path.join([File.cwd!, "bundles"])

config :cog, Cog.Command.Pipeline,
  interactive_timeout: {60, :sec},
  trigger_timeout: {300, :sec}

config :cog, Cog.Command.Service,
  data_path: data_dir("service_data")

config :cog, :custom_template_dir, System.get_env("COG_CUSTOM_TEMPLATE_DIR")

# Set these to zero (0) to disable caching
config :cog, :command_cache_ttl, {60, :sec}
config :cog, :command_rule_ttl, {10, :sec}
config :cog, :template_cache_ttl, {60, :sec}
config :cog, :user_perms_ttl, {10, :sec}

# Enable/disable user self-registration
config :cog, :self_registration, System.get_env("COG_ALLOW_SELF_REGISTRATION") != nil || false

config :cog, :emqttc,
  log_level: :info

# How many levels deep do we expand aliases, '0' disables aliases
config :cog, :max_alias_expansion, 5

# ========================================================================
# Logging

common_metadata = [:module, :line]
common_log_format = "$dateT$time $metadata[$level] $levelpad$message\n"

config :logger,
  utc_log: true,
  level: :info,
  backends: [:console,
             {LoggerFileBackend, :flywheel_log}]

config :logger, :console,
  metadata: common_metadata,
  format: common_log_format

config :logger, :cog_log,
  metadata: common_metadata,
  format: common_log_format,
  path: data_dir("cog.log")

if System.get_env("COG_SASL_LOG") != nil do
config :logger,
  handle_sasl_reports: true
end

config :lager, :error_logger_redirect, false
config :lager, :error_logger_whitelist, [Logger.ErrorHandler]
config :lager, :crash_log, false

config :probe, log_directory: data_dir("audit_logs")

# ========================================================================
# Database Setup

config :cog, ecto_repos: [Cog.Repo]

config :cog, Cog.Repo,
  adapter: Ecto.Adapters.Postgres,
  url: (case System.get_env("DATABASE_URL") do
          nil -> "ecto://#{System.get_env("USER")}@localhost/cog_#{Mix.env}"
          url -> url
        end),
  pool_size: ensure_integer(System.get_env("COG_DB_POOL_SIZE")) || 10,
  pool_timeout: ensure_integer(System.get_env("COG_DB_POOL_TIMEOUT")) || 15000,
  timeout: ensure_integer(System.get_env("COG_DB_TIMEOUT")) || 15000,
  parameters: [timezone: 'UTC'],
  loggers: [{Cog.Util.EctoLogger, :log, []}],
  ssl: ensure_boolean(System.get_env("COG_DB_SSL")) || false

# ========================================================================

config :cog, Carrier.Messaging.Connection,
  host: System.get_env("COG_MQTT_HOST") || "127.0.0.1",
  port: ensure_integer(System.get_env("COG_MQTT_PORT")) || 1883

# Uncomment the next three lines and edit ssl_cert to point to your
# SSL certificate.
# Note: SSL certification verification can be disabled by setting
# "ssl: :no_verify". We strongly recommend disabling verification for
# development or debugging ONLY.
#config :cog, Carrier.Messaging.Connection,
#  ssl: true,
#  ssl_cert: "server.crt"

# ========================================================================
# Web Endpoints

config :cog, Cog.Endpoint,
  http: [port: System.get_env("PORT") || System.get_env("COG_API_PORT") || 4000 ],
  url: gen_public_url_config(Cog.Endpoint),
  root: Path.dirname(__DIR__),
  debug_errors: false,
  cache_static_lookup: false,
  check_origin: true,
  render_errors: [accepts: ~w(json)],
  pubsub: [name: Carrier.Messaging.Connection,
           adapter: Phoenix.PubSub.PG2]

config :cog, Cog.TriggerEndpoint,
  http: [port: System.get_env("COG_TRIGGER_PORT") || 4001],
  url: gen_public_url_config(Cog.TriggerEndpoint),
  root: Path.dirname(__DIR__),
  debug_errors: false,
  cache_static_lookup: false,
  check_origin: true,
  render_errors: [accepts: ~w(json)]

config :cog, Cog.ServiceEndpoint,
  http: [port: System.get_env("COG_SERVICE_PORT") || 4002],
  url: gen_public_url_config(Cog.ServiceEndpoint),
  root: Path.dirname(__DIR__),
  debug_errors: false,
  cache_static_lookup: false,
  check_origin: true,
  render_errors: [accepts: ~w(json)]

config :cog, :token_lifetime, {1, :week}
config :cog, :token_reap_period, {1, :day}

# Trigger timeouts are defined according to the needs of the
# requestor, which includes network roundtrip time, as well as Cog's
# internal processing. Cog itself can't wait that long to respond, as
# that'll be guaranteed to exceed the HTTP requestor's timeout. As
# such, we'll incorporate a buffer into our internal timeout. Defined
# as seconds
config :cog, :trigger_timeout_buffer, (System.get_env("COG_TRIGGER_TIMEOUT_BUFFER") || 2)

# ========================================================================
# Emails

config :cog, Cog.Mailer,
  adapter: Bamboo.SMTPAdapter,
  server: System.get_env("COG_SMTP_SERVER"),
  port: ensure_integer(System.get_env("COG_SMTP_PORT")),
  username: System.get_env("COG_SMTP_USERNAME"),
  password: System.get_env("COG_SMTP_PASSWORD"),
  tls: :if_available, # can be `:always` or `:never`
  ssl: (ensure_boolean(System.get_env("COG_SMTP_SSL")) || false),
  retries: (System.get_env("COG_SMTP_RETRIES") || 1)

config :cog, :email_from, System.get_env("COG_EMAIL_FROM")
config :cog, :password_reset_base_url, System.get_env("COG_PASSWORD_RESET_BASE_URL")

import_config "slack.exs"
import_config "hipchat.exs"

import_config "#{Mix.env}.exs"
