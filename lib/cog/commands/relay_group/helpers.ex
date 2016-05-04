defmodule Cog.Commands.RelayGroup.Helpers do
  alias Cog.Repository.RelayGroups
  alias Cog.Repository.Relays

  @doc """
  Returns a relay group by name or an error tuple.
  """
  @spec get_relay_group(String.t) :: {:ok, %Cog.Models.RelayGroup{}} | {:error, any()}
  def get_relay_group(group_name) do
    case RelayGroups.by_name(group_name) do
      {:ok, relay_group} ->
        {:ok, relay_group}
      {:error, :not_found} ->
        {:error, {:relay_group_not_found, group_name}}
    end
  end

  @doc """
  Returns al list of relays based on a list of relay names.
  """
  @spec get_relays(List.t) :: {:ok, [%Cog.Models.RelayGroup{}]} | {:error, any()}
  def get_relays(relay_names) do
    case Relays.by_name(relay_names) do
      {:ok, relays} ->
        {:ok, relays}
      {:error, :not_found} ->
        {:error, {:relays_not_found, relay_names}}
    end
  end

  @doc """
  Verifies that the list of relay name is included in the list of relays
  """
  @spec verify_relays([%Cog.Models.Relay{}], [String.t]) :: :ok | {:error, any()}
  def verify_relays(relays, relay_names) do
    requested_relays = MapSet.new(relay_names)
    found_relays = MapSet.new(relays, &(&1.name))

    missing_relays = MapSet.difference(requested_relays, found_relays)
    |> MapSet.to_list

    case missing_relays do
      [] ->
        :ok
      missing ->
        {:error, {:relays_not_found, missing}}
    end
  end

end
