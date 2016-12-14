defmodule Cog.Commands.RelayGroup do
  alias Cog.Models.RelayGroup
  alias Cog.Commands.Relay

  @doc """
  Returns a map representing a relay group from a relay group model.
  """
  @spec json(%RelayGroup{}) :: Map.t
  def json(relay_group) do
    %{"name" => relay_group.name,
      "id" => relay_group.id,
      "created_at" => relay_group.inserted_at,
      "relays" => Enum.map(relay_group.relays, &Relay.ViewHelpers.render/1),
      "bundles" => Enum.map(relay_group.bundles, &bundle_json/1)}
  end

  defp bundle_json(bundle) do
    %{"name" => bundle.name}
  end
end
