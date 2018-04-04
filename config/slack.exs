use Mix.Config
import Cog.Config.Helpers

config :cog, Cog.Chat.Slack.Provider,
  api_token: System.get_env("SLACK_API_TOKEN"),
  enable_threaded_response: ensure_boolean(System.get_env("SLACK_ENABLE_THREADED_RESPONSES")),
  enable_thread_broadcast: ensure_boolean(System.get_env("SLACK_ENABLE_THREAD_BROADCAST"))
