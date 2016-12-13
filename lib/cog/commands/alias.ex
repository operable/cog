defmodule Cog.Commands.Alias do
  use Cog.Command.GenCommand.Base, bundle: Cog.Util.Misc.embedded_bundle
  alias Cog.Commands.Alias
  require Cog.Commands.Helpers, as: Helpers

  Helpers.usage(:root)

  @description "Manage command aliases"

  @arguments "[subcommand]"

  @subcommands %{
    "create <alias> <pipeline>" => "Create a new alias visible to the creator",
    "move <alias> <site|user>:<new-alias>" => "Move an alias between user and site visibility and optionally rename alias",
    "delete <alias>" => "Delete alias",
    "list [pattern]" => "List all aliases optionally filtered by a pattern (supports basic wildcard with \"*\")"
  }

  @examples """
  Create a new alias:

    alias create my-awesome-alias "echo \"My Awesome Alias\""

  Move a user alias to a site alias:

    alias move my-awesome-alias site:awesome-alias

  Delete an alias:

    alias delete awesome-alias

  View all user and site aliases:

    alias list
  """

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:alias allow"

  def handle_message(req, state) do
    if Helpers.flag?(req.options, "help") do
      {:ok, template, data} = show_usage
      {:reply, req.reply_to, template, data, state}
    else
      Alias.List.handle_message(req, state)
    end
  end

end
