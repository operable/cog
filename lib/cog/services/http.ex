defmodule Cog.Services.Http do
  use Cog.GenService
  require Logger

  def handle_message("get", req, state) do
    response = fetch_content(req)
    |> maybe_uncompress
    |> Map.fetch!(:body)
    |> Poison.decode!

    {:reply, response, req, state}
  end

  defp fetch_content(req) do
    key = req.parameters["url"]
    case cache_lookup(key) do
      nil ->
        make_request(:get, req.parameters["url"], req.parameters["headers"])
        |> cache_insert(key)
      entry ->
        entry
    end
  end

  defp make_request(:get, url, nil) do
    Logger.debug("Requesting url #{url}")
    HTTPotion.get(url)
  end
  defp make_request(:get, url, headers) do
    Logger.debug("Requesting url #{url}")
    HTTPotion.get(url, headers: Map.to_list(headers))
  end

  defp maybe_uncompress(response) do
    case response.headers[:"Content-Encoding"] do
      "gzip" ->
        %{response | :body => :zlib.gunzip(response.body)}
      _ -> response
    end
  end
end
