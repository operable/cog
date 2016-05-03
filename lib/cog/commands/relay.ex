defmodule Cog.Commands.Relay do
  use Cog.Command.GenCommand.Base, bundle: Cog.embedded_bundle
  alias Cog.Commands.Relay
  alias Cog.Commands.Helpers

  @moduledoc """
  Manages relays
  Usage relay <subcommand> [flags]

  Subcommands
  * list -- Lists relays and their status
  * update -- Update the name or description of a relay
  """

  permission "manage_relays"

  rule "when command is #{Cog.embedded_bundle}:relay must have #{Cog.embedded_bundle}:manage_relays"

  # general options
  option "help", type: "bool", short: "h"

  # list options
  option "group", type: "bool", short: "g"
  option "verbose", type: "bool", short: "v"

  # update options
  option "name", type: "string"
  option "description", type: "string"

  def handle_message(req, state) do
    {subcommand, args} = Helpers.get_subcommand(req.args)

    result = case subcommand do
      "list" ->
        Relay.List.list_relays(req)
      "update" ->
        Relay.Update.update_relay(req, args)
      nil ->
        show_usage
      invalid ->
        {:error, {:unknown_subcommand, invalid}}
    end

    case result do
      {:ok, template, data} ->
        {:reply, req.reply_to, template, data, state}
      {:error, err} ->
        {:error, req.reply_to, Helpers.error(err), state}
    end
  end

  @doc """
  Returns "enabled" for an enabled relay and "disabled" for
  a disabled relay"
  """
  @spec relay_status(%Cog.Models.Relay{}) :: :enabled | :disabled
  ## This function is public because it's used in both subcommands
  def relay_status(%{enabled: true}),
    do: :enabled
  def relay_status(%{enabled: false}),
    do: :disabled

  defp show_usage do
    {:ok, "relay-usage", %{usage: @moduledoc}}
  end
end
