defmodule Cog.Telemetry do
  require Logger

  @telemetry_url "https://telemetry.operable.io"

  def send_event(type) do
    if telemetry_enabled do
      spawn fn ->
        case build_event(type) do
          {:ok, event_body} ->
            post_telemetry(type, event_body)
        end
      end
    end
  end

  defp build_event(:start) do
    bundle_id =
      "operable"
      |> Cog.Queries.Bundles.bundle_id_from_name
      |> Cog.Repo.one

    case bundle_id do
      nil ->
        {:error, "Cannot find ID for embedded bundle."}
      bundle_id ->
        telemetry_id = Base.encode16(:crypto.hash(:sha256, bundle_id))
        {:ok, version} = :application.get_key(:cog, :vsn)
        {:ok, %{ cog: %{ id: telemetry_id, version: to_string(version) }}}
    end
  end

  defp telemetry_enabled do
    Application.fetch_env!(:cog, :telemetry)
  end

  defp post_telemetry(event_type, event_body) do
    post_url = @telemetry_url <> "/events/" <> Atom.to_string(event_type)
    post_body = Poison.encode!(event_body)

    Logger.info "Sending telemetry data to Operable: #{post_body}"
    Logger.info "To disable telemetry, set the COG_TELEMETRY environment variable to false."

    HTTPotion.post(post_url, headers: ["Content-Type": "application/json",
                                       "Accepts": "application/json"],
                             body: post_body)
  end
end
