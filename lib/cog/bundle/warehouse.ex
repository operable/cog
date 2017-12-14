defmodule Cog.Bundle.Warehouse do
  @registry_url "https://warehouse.cog.bot"

  def get_config(bundle, version) do
    headers = ["Accepts": "application/json"]
    response = HTTPotion.get(@registry_url <> "/api/bundles/#{bundle}/#{version}.json", headers: headers)

    case response do
      %HTTPotion.Response{status_code: 200, body: body} ->
        {:ok, Poison.decode!(body)}
      %HTTPotion.Response{status_code: 404} ->
        case version do
          "latest" ->
            {:error, {:not_found, bundle}}
          version ->
            {:error, {:not_found, bundle, version}}
        end
      _ ->
        {:error, :registry_error}
    end
  end
end
