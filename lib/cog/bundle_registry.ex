defmodule Cog.BundleRegistry do
  @registry_url "https://bundles.operable.io"

  def get_config(bundle, version) do
    headers = ["Accepts": "application/json"]
    response = HTTPotion.get(@registry_url <> "/api/bundles/#{bundle}/#{version}", headers: headers)

    case response do
      %HTTPotion.Response{status_code: 200, body: body} ->
        {:ok, Poison.decode!(body)}
      %HTTPotion.Response{status_code: 404} ->
        {:error, "Bundle not found"}
    end
  end
end
