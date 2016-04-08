defmodule Cog.TriggerEndpoint do
  use Phoenix.Endpoint, otp_app: :cog

  plug Plug.RequestId
  plug Plug.Logger

  plug Cog.TriggerRouter

end
