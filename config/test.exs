use Mix.Config

config :logger, :console,
  level: :info

config :cog,
  adapter: Cog.Adapters.Null

config :cog, Cog.Adapters.Slack,
  rtm_token: System.get_env("SLACK_RTM_TOKEN"),
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

config :cog, Cog.Repo,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_timeout: 30000

config :carrier, Carrier.Messaging.Connection,
  host: "127.0.0.1",
  port: 1884,
  log_level: :info

config :cog,
  :template_cache_ttl, {1, :sec}

config :cog, :services,
  http_cache_ttl: 0

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
  server: false

config :cog, Cog.Passwords,
  # 4-round hashing for test only
  salt: "$2b$04$vpRaVzxRGVTr6wf6jPQO5O"

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
