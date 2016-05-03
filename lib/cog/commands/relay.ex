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


  relay list
  Lists relays.

  Usage:
  relay list [-g <group>] [-v <verbose>]

  Flags:
  -g, --group     Group relays by relay group
  -v, --verbose   Include additional relay details
  """

  permission "manage_relays"

  rule "when command is #{Cog.embedded_bundle}:relay must have #{Cog.embedded_bundle}:manage_relays"

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
        :usage
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
end
