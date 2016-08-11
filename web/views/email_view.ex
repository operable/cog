defmodule Cog.EmailView do
  use Cog.Web, :view
  require Logger

  @doc """
  Returns true if the password_reset_base_url var is set. password_reset_base_url
  is the url of the external web application utilizing the password reset endpoints
  of Cog. Internally this is the flywheel password reset url.
  """
  def webui?(),
    do: not(is_nil(Application.get_env(:cog, :password_reset_base_url)))

  def reset_url(token) do
    base_url = Application.get_env(:cog, :password_reset_base_url, "")
    |> URI.parse

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
