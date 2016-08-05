defmodule Cog.EmailView do
  use Cog.Web, :view
  require Logger

  def reset_url(token) do
    base_url = case Application.get_env(:cog, :password_reset_base_url, nil) do
      nil ->
        Logger.warn("""
        Base URL not set for password reset, defaulting to 'localhost'.
        The base url is the url Cog sends to users when a password reset is requested.

        Please set the env var 'COG_PASSWORD_RESET_BASE_URL'.
        """)

        "localhost"

      base_url ->
        base_url
    end

    URI.parse(base_url)
    |> Map.put(:query, "token=#{token}")
    |> URI.to_string
  end
end
