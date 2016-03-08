defmodule Cog.Adapters.IRC.Config do
  use Cog.Adapters.Config,
    key: Cog.Adapters.IRC,
    schema:
      [irc:
        [{:host,    [:required]},
         {:port,    [:required, :integer]},
         {:channel, [:required]},
         {:nick,    [:required]},
         :user,
         :password,
         {:use_ssl, [:required, :boolean]}]]
end
