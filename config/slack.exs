use Mix.Config

config :cog, Cog.Chat.Slack.Provider,
  api_token: System.get_env("SLACK_API_TOKEN")
