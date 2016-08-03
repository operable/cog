defmodule Cog.EmailView do
  use Cog.Web, :view

  def reset_url(token) do
    Application.fetch_env!(:cog, :password_reset_base_url)
    |> URI.parse
    |> Map.put(:query, "token=#{token}")
    |> URI.to_string
  end
end
