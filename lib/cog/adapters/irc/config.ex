defmodule Cog.Adapters.IRC.Config do
  @config Cog.Adapters.IRC
  @schema [irc: [{:host,    [:required]},
                 {:port,    [:required, :integer]},
                 {:nick,    [:required]},
                 {:channel, [:required]},
                 {:use_ssl, [:required, :boolean]}]]

  use Cog.Adapters.Config
end
