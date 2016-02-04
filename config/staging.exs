use Mix.Config

config :logger, :console,
  level: :info

config :cog,
  adapter: System.get_env("COG_ADAPTER") || Cog.Adapters.Slack

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

config :carrier, Carrier.Messaging.Connection,
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
