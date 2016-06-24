defmodule Cog.Commands.Relay.Info do
  require Cog.Commands.Helpers, as: Helpers

  alias Cog.Repository.Relays

  Helpers.usage """
  Get detailed information about a relay.

  USAGE
    relay info [FLAGS] <name>

  ARGS
    name    The relay to get info about

  FLAGS
    -h, --help    Display this usage info

  EXAMPLES

    relay info foo
  """

  def info(%{options: %{"help" => true}}, _args),
    do: show_usage
  def info(_req, [name]) when is_binary(name) do
    case Relays.by_name(name) do
      {:ok, relay} ->
        {:ok, "relay-info", render(relay)}
      {:error, :not_found} ->
        {:error, {:resource_not_found, "relay", name}}
    end
  end
  def info(_, [_]),
    do: {:error, :wrong_type}
  def info(_, []),
    do: {:error, {:not_enough_args, 1}}
  def info(_, _),
    do: {:error, {:too_many_args, 1}}

  # Temporary measure to reuse as much rendering logic from the List
  # subcommand as possible until we use views to do it consistently
  # everywhere.
  defp render(relay) do
    Cog.Commands.Relay.json(relay)
    |> Map.put("relay_groups", Enum.map(relay.groups, &Cog.Commands.Relay.List.relay_group_json/1))
    |> Map.put("_show_groups", true)

  end

end
