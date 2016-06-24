defmodule Cog.Commands.Relay do
  use Cog.Command.GenCommand.Base, bundle: Cog.embedded_bundle
  alias Cog.Commands.Relay
  alias Cog.Commands.Helpers

  @description "Manage relays"

  @moduledoc """
  #{@description}

  USAGE
    relay <subcommand>

  SUBCOMMANDS
    list      Lists relays and their status
    update    Update the name or description of a relay
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
      "info" ->
        Relay.Info.info(req, args)
      "list" ->
        Relay.List.list_relays(req)
      "update" ->
        Relay.Update.update_relay(req, args)
      nil ->
        show_usage
      other ->
        {:error, {:unknown_subcommand, other}}
    end

    case result do
      {:ok, template, data} ->
        {:reply, req.reply_to, template, data, state}
      {:ok, message} ->
        {:reply, req.reply_to, message, state}
      {:error, err} ->
        {:error, req.reply_to, error(err), state}
    end
  end

  defp show_usage do
    {:ok, "usage", %{usage: @moduledoc}}
  end

  defp error(:wrong_type),
    do: "Arguments must be strings"
  defp error(error),
    do: Helpers.error(error)
end
