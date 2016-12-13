defmodule Cog.Commands.Group do
  use Cog.Command.GenCommand.Base, bundle: Cog.Util.Misc.embedded_bundle
  require Cog.Commands.Helpers, as: Helpers
  alias Cog.Commands.Group

  Helpers.usage(:root)

  @description "Manage user groups"

  @arguments "[subcommand]"

  @subcommands %{
    "list" => "List user groups (default)",
    "info <group>" => "Get info about a specific user group",
    "create <group>" => "Creates a new user group",
    "delete <group>" => "Deletes a user group",
    "member <subcommand>" => "Manage members of user groups",
    "rename <group> <new-group>" => "Rename a group",
    "role <subcommand>" => "Manage roles associated with user groups"
  }

  permission "manage_groups"
  permission "manage_users"

  rule ~s(when command is #{Cog.Util.Misc.embedded_bundle}:group must have #{Cog.Util.Misc.embedded_bundle}:manage_groups)

  def handle_message(req, state) do
    if Helpers.flag?(req.options, "help") do
      {:ok, template, data} = show_usage
      {:reply, req.reply_to, template, data, state}
    else
      Group.List.handle_message(req, state)
    end
  end

  def error(:wrong_type),
    do: "Arguments must be strings"
  def error({:protected_group, name}),
    do: "Cannot alter protected group #{name}"
  def error(error),
    do: Helpers.error(error)

end
