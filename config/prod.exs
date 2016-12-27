use Mix.Config

config :lager, :handlers,
  [{LagerLogger, [level: :error]}]

config :comeonin,
  bcrypt_log_rounds: 14

config :cog, CogChat.Adapter,
  cache_ttl: {60, :sec}
