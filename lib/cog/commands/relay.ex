defmodule Cog.Commands.Relay do
  use Cog.Command.GenCommand.Base, bundle: Cog.Util.Misc.embedded_bundle
  alias Cog.Commands.Relay
  require Cog.Commands.Helpers, as: Helpers

  Helpers.usage(:root)

  @description "Manage relays"

  @arguments "<subcommand>"

  @subcommands %{
    "list" => "Lists relays and their status (default)",
    "info <relay>" => "Get information on a specific relay",
    "update" => "Update the name or description of a relay"
  }

  permission "manage_relays"

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:relay must have #{Cog.Util.Misc.embedded_bundle}:manage_relays"

  def handle_message(req, state) do
    if Helpers.flag?(req.options, "help") do
      {:ok, template, data} = show_usage
      {:reply, req.reply_to, template, data, state}
    else
      Relay.List.handle_message(req, state)
    end
  end

  def error(:wrong_type),
    do: "Arguments must be strings"
  def error(error),
    do: Helpers.error(error)
end
