defmodule Cog.Commands.Alias do
  use Cog.Command.GenCommand.Base, bundle: Cog.embedded_bundle
  alias Cog.Commands.Alias
  alias Cog.Commands.Helpers

  @description "Manage command aliases"

  @moduledoc """
  #{@description}

  USAGE
    alias <subcommand>

  SUBCOMMANDS
    create <alias-name> <alias-definition>             creates a new alias visible to the creating user.
    move <alias-name> <site | user>:[new-alias-name]   moves aliases between user and site visibility. Optionally renames aliases.
    delete <alias-name>                                deletes aliases
    list [pattern]                                    Returns the list of aliases optionally filtered by pattern. Pattern support basic wildcards with '*'.

  EXAMPLES
    alias create my-awesome-alias "echo \"My Awesome Alias\""
    > user:my-awesome-alias has been created

    alias move my-awesome-alias site:awesome-alias
    > Moved user:my-awesome-alias to site:awesome-alias

    alias delete awesome-alias
    > Removed site:awesome-alias

    alias list
    > Name: 'my-awesome-alias'
      Visibility: 'user'
      Pipeline: 'echo my-awesome-alias'

      Name: 'my-other-awesome-alias'
      Visibility: 'site'
      Pipeline: 'echo my-other-awesome-alias'
  """

  rule "when command is #{Cog.embedded_bundle}:alias allow"

  def handle_message(req, state) do
    {subcommand, args} = get_subcommand(req.args)

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
        Alias.List.list_command_aliases(req, args)
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

  # TODO: delete this!
  defp get_subcommand([]),
    do: {nil, []}
  defp get_subcommand([subcommand | args]),
    do: {subcommand, args}

end
