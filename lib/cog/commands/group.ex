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
  rule ~s(when command is #{Cog.Util.Misc.embedded_bundle}:group with arg[0] == 'member' must have #{Cog.Util.Misc.embedded_bundle}:manage_users)

  def handle_message(req, state) do
    {subcommand, args} = Helpers.get_subcommand(req.args)

    result = case subcommand do
      "member" ->
        Group.Member.manage_members(req, args)
      "rename" ->
        Group.Rename.rename(req, args)
      "role" ->
        Group.Role.manage_roles(req, args)
      "info" ->
        Group.Info.get_info(req, args)
      nil ->
        if Helpers.flag?(req.options, "help") do
          show_usage
        else
          Group.List.handle_message(req, state)
        end
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

  def error(:wrong_type),
    do: "Arguments must be strings"
  def error({:protected_group, name}),
    do: "Cannot alter protected group #{name}"
  def error(error),
    do: Helpers.error(error)

end
