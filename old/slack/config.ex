defmodule Cog.Adapters.Slack.Config do
  use Cog.Adapters.Config,
    key: Cog.Adapters.Slack,
    schema: [api:
              [{:token, [:required], :api_token},
               {:cache_ttl, [:integer], :api_cache_ttl}]]
end
