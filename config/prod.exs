use Mix.Config

config :logger, :console,
  level: :info

config :lager, :handlers,
  [{LagerLogger, [level: :error]}]

config :comeonin,
  bcrypt_log_rounds: 14

config :cog, Cog.Chat.Adapter,
  providers: [slack: Cog.Chat.SlackProvider],
  chat: :slack
