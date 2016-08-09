defmodule Cog.EmailView do
  use Cog.Web, :view
  require Logger

  def reset_url(token) do
    base_url = case Application.get_env(:cog, :password_reset_base_url, nil) do
      nil ->
        Logger.warn("""
        Base URL not set for password reset, defaulting to 'localhost'.
        The base url is used to generate a password reset url when a request
        to reset a password is received. The password reset url is generated
        by appending a token to the base url.

        Please set the env var 'COG_PASSWORD_RESET_BASE_URL'.
        """)

        %URI{host: "localhost"}

      base_url ->
        URI.parse(base_url)
    end

    %{base_url | path: build_path(base_url.path, token)}
    |> URI.to_string
  end

  defp build_path(nil, token),
    do: "/#{token}"
  defp build_path(path, token) do
    String.split(path, "/") ++ [token]
    |> Enum.join("/")
  end
end
