defmodule Cog.Command.Service.MemoryClient do
  require HTTPotion

  @service_url "/v1/services"
  @memory_url "/memory/1.0.0"

  def fetch(base_url, token, key) do
    request(:get, base_url, token, key)
  end

  def accum(base_url, token, key, value) do
    body = %{"op" => "accum", "value" => value}
    request(:post, base_url, token, key, body)
  end

  def join(base_url, token, key, value) do
    body = %{"op" => "join", "value" => value}
    request(:post, base_url, token, key, body)
  end

  def replace(base_url, token, key, value) do
    request(:put, base_url, token, key, value)
  end

  def delete(base_url, token, key) do
    request(:delete, base_url, token, key)
  end

  defp request(method, base_url, token, key) when method in [:get, :delete] do
    url = build_url(base_url, key)
    headers = build_headers(token)
    response = HTTPotion.request(method, url, headers: headers)
    Poison.decode!(response.body)
  end

  defp request(method, base_url, token, key, body) when method in [:post, :put] do
    url = build_url(base_url, key)
    headers = build_headers(token)
    response = HTTPotion.post(url, headers: headers, body: Poison.encode!(body))
    Poison.decode!(response.body)
  end

  defp build_url(base_url, key) do
    base_url <> @service_url <> @memory_url <> "/#{key}"
  end

  defp build_headers(token) do
    ["Authorization": "pipeline #{token}",
     "Accepts":       "application/json",
     "Content-Type":  "application/json"]
  end
end
