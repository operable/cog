defmodule Cog.Commands.Relay.Update do
  alias Cog.Repository.Relays
  alias Cog.Commands.Helpers

  @moduledoc """
  Updates relay name and/or description.

  Usage:
  relay update <relay name> [-n <name>] [-d <description>] [-h <help>]

  Flags:
  -h, --help           Display this usage info
  -n, --name           Update the relay's name
  -d, --description    Update the relay's description
  """

  @doc """
  Updates relays. Accepts a cog request and args. Returns either
  a success tuple or an error.
  """
  @spec update_relay(%Cog.Command.Request{}, List.t) :: {:ok, String.t, Map.t} | {:error, any()}
  def update_relay(req, arg_list) do
    if Helpers.flag?(req.options, "help") do
      show_usage
    else
      case Helpers.get_args(arg_list, 1) do
        {:ok, [relay_name]} ->
          case Relays.by_name(relay_name) do
            {:ok, relay} ->
              do_update(req, relay)
            {:error, :not_found} ->
              {:error, {:relay_not_found, relay_name}}
          end
        {:error, {:not_enough_args, _count}} ->
          show_usage("Missing required argument: relay name")
        {:error, {:too_many_args, _count}} ->
          show_usage("Too many arguments. You can only update one relay at a time.")
        error ->
          error
      end
    end
  end

  defp do_update(req, relay) do
    params = Map.take(req.options, ["name", "description"])
    case Relays.update(relay.id, params) do
      {:ok, updated_relay} ->
        {:ok, "relay-update", generate_response(updated_relay)}
      {:error, changeset} ->
        {:error, {:db_errors, changeset.errors}}
    end
  end

  defp generate_response(relay) do
    %{"name" => relay.name,
      "status" => Cog.Commands.Relay.relay_status(relay),
      "id" => relay.id}
  end

  def show_usage(error \\ nil) do
    {:ok, "usage", %{usage: @moduledoc, error: error}}
  end
end
