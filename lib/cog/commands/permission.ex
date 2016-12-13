defmodule Cog.Commands.Permission do
  use Cog.Command.GenCommand.Base, bundle: Cog.Util.Misc.embedded_bundle
  require Cog.Commands.Helpers, as: Helpers
  alias Cog.Commands.Permission.List

  Helpers.usage(:root)

  @description "Manage authorization permissions"

  @arguments "[subcommand]"

  @subcommands %{
    "list" => "List all permissions (default)",
    "info <permission>" => "Get detailed information about a specific permission",
    "create site:<permission>" => "Create a new site permission",
    "delete site:<permission>" => "Delete an existing site permission",
    "grant <permission> <role>" => "Grant a permission to a role",
    "revoke <permission> <role>" => "Revoke a permission from a group"
  }

  permission "manage_permissions"
  permission "manage_roles"

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:permission must have #{Cog.Util.Misc.embedded_bundle}:manage_permissions"

  def handle_message(req, state) do
    if Helpers.flag?(req.options, "help") do
      {:ok, template, data} =  show_usage
      {:reply, req.reply_to, template, data, state}
    else
      List.handle_message(req, state)
    end
  end

  def error(:invalid_permission),
    do: "Only permissions in the `site` namespace can be created or deleted; please specify permission as `site:<NAME>`"
  def error(:wrong_type),
    do: "Arguments must be strings"
  def error(error),
    do: Helpers.error(error)

end
