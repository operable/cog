defmodule Cog.EmailView do
  use Cog.Web, :view
  require Logger

  def webui? do
    if Application.get_env(:cog, :password_reset_base_url, false) == false do
      false
    else
      true
    end
  end

  def reset_url(token) do
    base_url = Application.get_env(:cog, :password_reset_base_url, nil)
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
