defmodule Cog.Adapters.IRC.Config do
  @config Cog.Adapters.IRC
  @schema [irc: [{:host,    [:required]},
                 {:port,    [:required, :integer]},
                 {:channel, [:required]},
                 {:nick,    [:required]},
                 {:use_ssl, [:required, :boolean]}]]

  use Cog.Adapters.Config
end
