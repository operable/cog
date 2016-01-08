defmodule Cog.Commands.Giphy do
  use Spanner.GenCommand.Base, bundle: Cog.embedded_bundle

  permission "giphy"
  rule "when command is #{Cog.embedded_bundle}:giphy must have #{Cog.embedded_bundle}:giphy"

  @giphy_url "http://api.giphy.com/v1/gifs/search"
  @limit "1"
  @api_key "dc6zaTOxFJmzC"

  def init(_, proxy),
    do: {:ok, proxy}

  def handle_message(req, proxy) do
    http_config = %{service: "http/get", parameters: %{url: build_url(req.args)}}
    response = Spanner.ServiceProxy.call(proxy, http_config)
    {:reply, req.reply_to, get_image_url(response), proxy}
  end

  defp build_url(query) do
    "#{@giphy_url}?q=#{query}&limit=#{@limit}&api_key=#{@api_key}"
  end

  defp get_image_url(%{"data" => [gif | _]}) do
    gif["url"]
  end
end
