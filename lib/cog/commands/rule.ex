defmodule Cog.Commands.Rule do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle

  alias Cog.Commands.Rule.{Info, List, Create, Delete}
  require Cog.Commands.Helpers, as: Helpers

  Helpers.usage(:root)

  @description "Manage authorization rules"

  @arguments "<subcommand>"

  @subcommands %{
    "list" => "List all rules (default)",
    "info <id>" => "Retrieve a rule by ID",
    "create [<rule> | <command> <permission>]" => "Add a rule",
    "delete <id>" => "Delete a rule",
  }

  option "command", type: "string", short: "c"

  permission "manage_commands"

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:rule must have #{Cog.Util.Misc.embedded_bundle}:manage_commands"

  def handle_message(req, state) do
    {subcommand, args} = Helpers.get_subcommand(req.args)

    result = case subcommand do
      "info" ->
        Info.info(req, args)
      "list" ->
        List.list(req, args)
      "create" ->
        Create.create(req, args)
      "delete" ->
        Delete.delete(req, args)
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
      {:ok, message} ->
        {:reply, req.reply_to, message, state}
      {:error, err} ->
        {:error, req.reply_to, error(err), state}
    end
  end

  defp error({:disabled, command}),
    do: "#{command} is not enabled. Enable a bundle version and try again"
  defp error({:command_not_found, command}),
    do: "Command #{inspect command} could not be found"
  defp error({:ambiguous, command}),
    do: "Command #{inspect command} refers to multiple commands. Please include a bundle in a fully qualified command name."
  defp error({:rule_invalid, {:invalid_rule_syntax, error}}),
    do: "Could not create rule: #{inspect error}"
  defp error({:rule_invalid, {:unrecognized_command, command}}),
    do: "Could not create rule: Unrecognized command #{inspect command}"
  defp error({:rule_invalid, {:unrecognized_permission, permission}}),
    do: "Could not create rule: Unrecognized permission #{inspect permission}"
  defp error({:rule_invalid, {:permission_bundle_mismatch, _permission}}),
    do: "Could not create rule with permission outside of command bundle or the \"site\" namespace"
  defp error({:rule_invalid, error}),
    do: "Could not create rule: #{inspect error}"
  defp error({:rule_not_found, [uuid]}),
    do: "Rule #{inspect uuid} could not be found"
  defp error({:rule_not_found, uuids}),
    do: "Rules #{Enum.map_join(uuids, ", ", &inspect/1)} could not be found"
  defp error({:rule_uuid_invalid, uuid}),
    do: "Invalid UUID #{inspect uuid}"
  defp error(:wrong_type),
    do: "Argument must be a string"
  defp error(error),
    do: Helpers.error(error)
end
