defmodule Cog.Commands.RelayGroup.Helpers do
  alias Cog.Repository.RelayGroups
  alias Cog.Repository.Relays
  alias Cog.Repo
  import Ecto.Query, only: [from: 2]

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
  Returns a list of relays based on a list of relay names.
  """
  @spec get_relays(List.t) :: {:ok, [%Cog.Models.Relay{}]} | {:error, any()}
  def get_relays(relay_names) do
    case Relays.by_name(relay_names) do
      {:ok, relays} ->
        {:ok, relays}
      {:error, :not_found} ->
        {:error, {:relays_not_found, relay_names}}
    end
  end

  @doc """
  Returns a list of bundles based on a list of bundle names.
  """
  @spec get_bundles(List.t) :: {:ok, [%Cog.Models.Bundle{}]} | {:error, any()}
  def get_bundles(bundle_names) do
    # TODO: Move this to a bundles repository
    case Repo.all(from b in Cog.Models.Bundle, where: b.name in ^bundle_names) do
      [] ->
        {:error, {:bundles_not_found, bundle_names}}
      bundles ->
        {:ok, bundles}
    end
  end

  @doc """
  Verifies that the entire list of values is contained in the list of models
  """
  @spec verify_list([%Cog.Models.Relay{}], [String.t], Atom.t) :: :ok | {:error, any()}
  def verify_list(models, values, key) do
    values = List.wrap(values)
             |> MapSet.new
    models = List.wrap(models)
             |> MapSet.new(&(Map.get(&1, key)))

    missing_values = MapSet.difference(values, models)
    |> MapSet.to_list

    case missing_values do
      [] ->
        :ok
      missing ->
        {:error, {:values_not_found, missing}}
    end
  end

end
