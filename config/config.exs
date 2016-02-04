use Mix.Config
use Cog.Config.Helpers

config :logger, :console,
  metadata: [:module, :line],
  format: {Adz, :text}

config :cog, Cog.Repo,
  adapter: Ecto.Adapters.Postgres,
  url: (case System.get_env("DATABASE_URL") do
          nil -> "ecto://#{System.get_env("USER")}@localhost/cog_#{Mix.env}"
          url -> url
        end),
  pool_timeout: String.to_integer(System.get_env("COG_DB_POOL_TIMEOUT") || "15000"),
  timeout: String.to_integer(System.get_env("COG_DB_TIMEOUT") || "15000"),
  parameters: [timezone: 'UTC']

config :cog, :command_prefix, "!"

# Set these to zero (0) to disable caching
config :cog, :command_cache_ttl, {60, :sec}
config :cog, :command_rule_ttl, {10, :sec}
config :cog, :template_cache_ttl, {60, :sec}
config :cog, :user_perms_ttl, {10, :sec}

config :cog, :services,
  http_cache_ttl: System.get_env("HTTP_SERVICE_CACHE_TTL") || 120

config :cog, :emqttc,
  log_level: :info

config :lager, :error_logger_redirect, false
config :lager, :error_logger_whitelist, [Logger.ErrorHandler]
config :lager, :crash_log, false
config :lager, :handlers, [{LagerLogger, [level: :debug]}]

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

config :carrier, :credentials_dir, data_dir("carrier_creds")

config :carrier, Carrier.Messaging.Connection,
  host: "127.0.0.1",
  port: 1883,
  log_level: :info

config :cog, Cog.Endpoint,
  http: [dispatch: [{:_, [{"/sockets/websocket", Cog.Handlers.WebSocketHandler, []},
                          {:_, Plug.Adapters.Cowboy.Handler, {Cog.Endpoint, []}}]}]],
  url: [host: "localhost"],
  root: Path.dirname(__DIR__),
  secret_key_base: "fiorJ+GXJ3AvOfVaPw5vShPkdflmguZnaNaPE4/UBog+6j5rtEIRNDtdSv9NykZD",
  render_errors: [accepts: ~w(html json)],
  pubsub: [name: Carrier.Messaging.Connection,
           adapter: Phoenix.PubSub.PG2]

config :cog, :token_lifetime, {1, :week}
config :cog, :token_reap_period, {1, :day}

# Configure phoenix generators
config :phoenix, :generators,
  migration: true,
  binary_id: false

config :cog, Cog.Bundle.BundleSup,
  bundle_root: Path.join([File.cwd!, "bundles"])

config :cog, :github_service,
  api_token: System.get_env("GITHUB_API_TOKEN")

config :cog, :aws_service,
  aws_access_key_id: System.get_env("AWS_ACCESS_KEY_ID"),
  aws_secret_access_key: System.get_env("AWS_SECRET_ACCESS_KEY")

import_config "#{Mix.env}.exs"
