defmodule Cog.Commands.Relay.ViewHelpers do
  # Temporary refactoring bridge to consolidate JSON generation logic
  # for Relay commands prior to using our API JSON views, as we do
  # elsewhere in the embedded bundle

  alias Cog.Models.Relay
  alias Cog.Models.RelayGroup

  def render(thing),
    do: render(thing, %{})

  def render(%Relay{}=relay, options),
    do: relay_json(relay, options)
  def render(relays, options) when is_list(relays),
    do: Enum.map(relays, &relay_json(&1, options))

  def template(base_template_name, %{"verbose" => true}),
    do: "#{base_template_name}-verbose"
  def template(base_template_name, _options),
    do: base_template_name

  ########################################################################

  defp relay_json(relay, options),
    do: relay |> json |> maybe_add_groups(relay, options)

  defp json(%Relay{}=relay) do
    %{"name"       => relay.name,
      "status"     => relay_status(relay),
      "id"         => relay.id,
      "created_at" => relay.inserted_at}
  end
  defp json(%RelayGroup{}=group),
    do: %{"name" => group.name}

  defp relay_status(%{enabled: true}),
    do: :enabled
  defp relay_status(%{enabled: false}),
    do: :disabled

  defp maybe_add_groups(relay_json, relay_model, %{"group" => true}) do
    relay_json
    |> Map.put("relay_groups", Enum.map(relay_model.groups, &json/1))
    |> Map.put("_show_groups", true)
  end
  defp maybe_add_groups(relay_json, _relay_model, _options),
    do: relay_json

end
