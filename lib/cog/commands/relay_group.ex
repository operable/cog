defmodule Cog.Commands.RelayGroup do
  alias Cog.Models.RelayGroup
  alias Cog.Commands.Relay
  alias Cog.Commands.Helpers

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

  def error({:bundles_not_found, missing_bundles}),
    do: "Some bundles could not be found: '#{Enum.join(missing_bundles, ", ")}'"
  def error({:relays_not_found, missing_relays}),
    do: "Some relays could not be found: '#{Enum.join(missing_relays, ", ")}'"
  def error({:relay_group_not_found, relay_group_name}),
    do: "No relay group with name '#{relay_group_name}' could be found"
  def error(error),
    do: Helpers.error(error)

  defp bundle_json(bundle) do
    %{"name" => bundle.name}
  end
end
