defmodule Cog.Pipeline.RelaySelector do

  alias Cog.Relay.Relays

  @moduledoc ~s"""
  Selects a Relay for a given bundle name and version
  """

  defstruct [:bundle_name, :bundle_version, :relay]

  @doc "Creates a new RelaySelector"
  @spec new(String.t, String.t) :: RelaySelector.t
  def new(bundle_name, bundle_version) do
    %__MODULE__{bundle_name: bundle_name, bundle_version: bundle_version}
  end

  @doc "Selects a Relay and updates the selector's internal state."
  @spec select(RelaySelector.t) :: {:ok, RelaySelector.t} | {:error, any}
  def select(%__MODULE__{bundle_name: name, bundle_version: version, relay: nil}=selector) do
    case Relays.pick_one(name, version) do
      {:ok, relay} ->
        selector = %{selector | relay: relay}
        {:ok, selector}
      error ->
      # Query DB to clarify error before reporting to the user
      if Cog.Repository.Bundles.assigned_to_group?(name) do
        error
      else
        {:error, {:no_relay_group, name}}
      end
    end
  end
  def select(%__MODULE__{bundle_name: name, bundle_version: version, relay: relay}=selector) do
    if Relays.relay_available?(relay, name, version) do
      {:ok, selector}
    else
      select(%{selector | relay: nil})
    end
  end

  @doc "Returns the name of the selected Relay"
  @spec relay(RelaySelector.t) :: String.t | nil
  def relay(%__MODULE__{relay: relay}), do: relay

  @doc "Constructs a MQTT topic for the named command"
  @spec relay_topic!(RelaySelector.t, String.t) :: String.t
  def relay_topic!(%__MODULE__{relay: nil, bundle_name: name, bundle_version: version}, command_name) do
    raise RuntimeError, message: "No relay selected for #{name}:#{command_name} v.#{version}. Forgot to call RelaySelector.select/1 first?"
  end
  def relay_topic!(%__MODULE__{}=selector, command_name) do
    "/bot/commands/#{selector.relay}/#{selector.bundle_name}/#{command_name}"
  end

end
