defmodule Cog.ServiceEndpoint do
  use Phoenix.Endpoint, otp_app: :cog

  plug Plug.RequestId
  plug Plug.Logger

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Poison

  plug Cog.ServiceRouter

  def public_url() do
    case Application.get_env(:cog, :services_url_base) do
      "" ->
        url()
      base ->
        base
    end
  end

end
