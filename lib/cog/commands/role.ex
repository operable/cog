defmodule Cog.Commands.Role do
  use Cog.Command.GenCommand.Base, bundle: Cog.Util.Misc.embedded_bundle
  require Cog.Commands.Helpers, as: Helpers

  alias Cog.Commands.Role.{Create, Delete, Grant, Info, List, Rename, Revoke}

  Helpers.usage(:root)

  @description "Manage authorization roles"

  @subcommands %{
    "list" => "List all roles (default)",
    "info <role>" => "Get detailed information about a specific role",
    "create <role>" => "Create a new role",
    "delete <role>" => "Delete an existing role",
    "grant <role> <group>" => "Grant a role to a group",
    "rename <role> <new-role>" => "Rename a role",
    "revoke <role> <group>" => "Revoke a role from a group"
  }

  permission "manage_roles"
  permission "manage_groups"

  # This rule is for the default
  rule "when command is #{Cog.Util.Misc.embedded_bundle}:role must have #{Cog.Util.Misc.embedded_bundle}:manage_roles"

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:role with arg[0] == create must have #{Cog.Util.Misc.embedded_bundle}:manage_roles"
  rule "when command is #{Cog.Util.Misc.embedded_bundle}:role with arg[0] == delete must have #{Cog.Util.Misc.embedded_bundle}:manage_roles"
  rule "when command is #{Cog.Util.Misc.embedded_bundle}:role with arg[0] == info must have #{Cog.Util.Misc.embedded_bundle}:manage_roles"
  rule "when command is #{Cog.Util.Misc.embedded_bundle}:role with arg[0] == list must have #{Cog.Util.Misc.embedded_bundle}:manage_roles"
  rule "when command is #{Cog.Util.Misc.embedded_bundle}:role with arg[0] == grant must have #{Cog.Util.Misc.embedded_bundle}:manage_groups"
  rule "when command is #{Cog.Util.Misc.embedded_bundle}:role with arg[0] == rename must have #{Cog.Util.Misc.embedded_bundle}:manage_roles"
  rule "when command is #{Cog.Util.Misc.embedded_bundle}:role with arg[0] == revoke must have #{Cog.Util.Misc.embedded_bundle}:manage_groups"

  def handle_message(req, state) do
    {subcommand, args} = Helpers.get_subcommand(req.args)

    result = case subcommand do
               "create" -> Create.create(req, args)
               "delete" -> Delete.delete(req, args)
               "grant"  -> Grant.grant(req, args)
               "info"   -> Info.info(req, args)
               "list"   -> List.list(req, args)
               "rename" -> Rename.rename(req, args)
               "revoke" -> Revoke.revoke(req, args)
               nil ->
                 if Helpers.flag?(req.options, "help") do
                   show_usage
                 else
                   List.list(req, args)
                 end
               other ->
                 {:error, {:unknown_subcommand, other}}
             end

    case result do
      {:ok, template, data} ->
         {:reply, req.reply_to, template, data, state}
      {:ok, data} ->
        {:reply, req.reply_to, data, state}
      {:error, err} ->
        {:error, req.reply_to, error(err), state}
    end
  end

  ########################################################################

  defp error({:permanent_role_grant, role_name, group_name}),
    do: "Cannot revoke role #{inspect role_name} from group #{inspect group_name}: grant is permanent"
  defp error({:protected_role, name}),
    do: "Cannot alter protected role #{name}"
  defp error(:wrong_type), # TODO: put this into helpers, take it out of permission.ex
    do: "Arguments must be strings"
  defp error(error),
    do: Helpers.error(error)

end
