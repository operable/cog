defmodule Cog.EventHookEndpoint do
  use Phoenix.Endpoint, otp_app: :cog

  plug Plug.RequestId
  # plug Plug.Logger

  plug Plug.Parsers,
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: Poison

  plug Cog.EventHookRouter

end
