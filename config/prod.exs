use Mix.Config

config :logger, :console,
  level: :info

config :lager, :handlers,
  [{LagerLogger, [level: :error]}]

config :comeonin,
  bcrypt_log_rounds: 14
