defmodule Cog.Commands.Alias do
  use Cog.Command.GenCommand.Base, bundle: Cog.Util.Misc.embedded_bundle
  alias Cog.Commands.Alias
  require Cog.Commands.Helpers, as: Helpers

  # FIXME
  Helpers.usage(:root, "")

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
    {subcommand, args} = Helpers.get_subcommand(req.args)

    result = case subcommand do
               "create" ->
                 Alias.Create.create_new_user_command_alias(req, args)
               "move" ->
                 Alias.Move.move_command_alias(req, args)
               "delete" ->
                 Alias.Delete.delete_command_alias(req, args)
               "list" ->
                 Alias.List.list_command_aliases(req, args)
               nil ->
                 if Helpers.flag?(req.options, "help") do
                   show_usage
                 else
                   Alias.List.list_command_aliases(req, args)
                 end
               other ->
                 {:error, {:unknown_subcommand, other}}
             end

    case result do
      {:ok, template, data} ->
        {:reply, req.reply_to, template, data, state}
      {:error, err} ->
        {:error, req.reply_to, Helpers.error(err), state}
    end
  end

end
