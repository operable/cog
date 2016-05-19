defmodule Cog.Commands.Group do
  use Cog.Command.GenCommand.Base, bundle: Cog.embedded_bundle
  require Cog.Commands.Helpers, as: Helpers
  alias Cog.Commands.Group

  Helpers.usage :root, """
  Manage user groups

  USAGE
    group [FLAGS] <SUBCOMMAND>

  SUBCOMMANDS
    list      List user groups (Default)
    info      Get info about a specific user group
    create    Creates a new user group
    delete    Deletes a user group
    member    Manage members of user groups
    role      Manage roles associated with user groups

  FLAGS
    -h, --help    Display this usage info
  """

  permission "manage_groups"
  permission "manage_users"

  rule ~s(when command is #{Cog.embedded_bundle}:group must have #{Cog.embedded_bundle}:manage_groups)
  rule ~s(when command is #{Cog.embedded_bundle}:group with arg[0] == 'member' must have #{Cog.embedded_bundle}:manage_users)

  # list options
  option "verbose", type: "bool", short: "v"

  def handle_message(req, state) do
    {subcommand, args} = Helpers.get_subcommand(req.args)

    result = case subcommand do
      "list" ->
        Group.List.list_groups(req, args)
      "create" ->
        Group.Create.create_group(req, args)
      "delete" ->
        Group.Delete.delete_group(req, args)
      "member" ->
        Group.Member.manage_members(req, args)
      "role" ->
        Group.Role.manage_roles(req, args)
      "info" ->
        Group.Info.get_info(req, args)
      nil ->
        if Helpers.flag?(req.options, "help") do
          show_usage
        else
          Group.List.list_groups(req, args)
        end
      invalid ->
        suggestion = Enum.max_by(["list", "create", "delete", "member", "role", "info"],
                                 &String.jaro_distance(&1, invalid))
        show_usage(error({:unknown_subcommand, invalid, suggestion}))
    end

    case result do
      {:ok, template, data} ->
        {:reply, req.reply_to, template, data, state}
      {:ok, message} ->
        {:reply, req.reply_to, message, state}
      {:error, err} ->
        {:error, req.reply_to, Helpers.error(err), state}
    end
  end

  defp error({:unknown_subcommand, invalid, suggestion}),
    do: "Unknown subcommand '#{invalid}'. Did you mean '#{suggestion}'?"
end
