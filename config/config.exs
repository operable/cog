use Mix.Config
use Cog.Config.Helpers

# ========================================================================
# Chat Adapters

config :cog,
  adapter: System.get_env("COG_ADAPTER") || "slack"

config :cog, :enable_spoken_commands, true

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

# ========================================================================
# Logging

config :logger, :console,
  metadata: [:module, :line],
  format: {Adz, :text}

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
# MQTT Messaging

config :emqttd, :access,
  auth: [anonymous: []],
  acl: [internal: [file: 'config/acl.conf', nomatch: :allow]]

config :emqttd, :broker,
  sys_interval: 60,
  retained: [max_message_num: 1024, max_payload_size: 65535],
  pubsub: [pool_size: 8]

config :emqttd, :mqtt,
  packet: [max_clientid_len: 128, max_packet_size: 163840],
  client: [ingoing_rate_limit: :'64KB/s', idle_timeout: 1],
  session: [max_inflight: 100, unack_retry_interval: 60,
            await_rel_timeout: 15, max_awaiting_rel: 0,
            collect_interval: 0, expired_after: 4],
  queue: [max_length: 100, low_watermark: 0.2, high_watermark: 0.6,
          queue_qos0: true],
  modules: [presence: [qos: 0]]

config :emqttd, :listeners,
  [{:mqtt, ensure_integer(System.get_env("COG_MQTT_PORT")) || 1883,
    [acceptors: 16,
     max_clients: 64,
     access: [allow: :all],
     sockopts: [backlog: 8,
                ip: System.get_env("COG_MQTT_HOST") || "127.0.0.1",
                recbuf: 4096,
                sndbuf: 4096,
                buffer: 4096]]}]

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
