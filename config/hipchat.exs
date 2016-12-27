use Mix.Config

config :cog_hipchat,
  api_root: System.get_env("HIPCHAT_API_ROOT") || "https://api.hipchat.com/v2",
  chat_host: System.get_env("HIPCHAT_CHAT_HOST") || "chat.hipchat.com",
  conf_host: System.get_env("HIPCHAT_CONF_HOST") || "conf.hipchat.com",
  api_token: System.get_env("HIPCHAT_API_TOKEN"),
  nickname: System.get_env("HIPCHAT_NICKNAME"),
  jabber_id: System.get_env("HIPCHAT_JABBER_ID"),
  jabber_password: System.get_env("HIPCHAT_JABBER_PASSWORD")
