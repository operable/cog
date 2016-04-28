defmodule Cog.ServiceEndpoint do
  use Phoenix.Endpoint, otp_app: :cog

  plug Plug.RequestId
  plug Plug.Logger

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Poison

  plug Cog.ServiceRouter

end
