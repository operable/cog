defmodule Cog.Commands.Rule do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.embedded_bundle

  alias Cog.Commands.Rule.{List, Create, Drop}
  require Cog.Commands.Helpers, as: Helpers
  require Logger

  Helpers.usage :root, """
  Manages rules for commands.

  USAGE
    rule [subcommand]

  FLAGS
    -h, --help  Display this usage info

  SUBCOMMANDS
    list    List all rules (default)
    create  Add a rule
    drop    Drop a rule
  """

  option "command", type: "string", short: "c"

  permission "manage_commands"

  rule "when command is #{Cog.embedded_bundle}:rule must have #{Cog.embedded_bundle}:manage_commands"

  def handle_message(req, state) do
    {subcommand, args} = Helpers.get_subcommand(req.args)

    result = case subcommand do
      "list" ->
        List.list(req, args)
      "create" ->
        Create.create(req, args)
      "drop" ->
        Drop.drop(req, args)
      nil ->
        if Helpers.flag?(req.options, "help") do
          show_usage
        else
          List.list(req, args)
        end
      invalid ->
        show_usage(error({:unknown_subcommand, invalid}))
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

  defp error({:command_not_found, command}),
    do: "Command #{inspect command} could not be found"
  defp error({:ambiguous, command}),
    do: "Command #{inspect command} refers to multiple commands. Please include a bundle in a fully qualified command name."
  defp error({:rule_invalid, error}),
    do: "Could not create rule: #{inspect error}"
  defp error({:rule_not_found, [uuid]}),
    do: "Rule #{inspect uuid} could not be found"
  defp error({:rule_not_found, uuids}),
    do: "Rules #{Enum.map_join(uuids, ", ", &inspect/1)} could not be found"
  defp error(:rule_non_site_namespace),
    do: "Could not create rule with permission outside of the \"site\" namespace"
  defp error({:rule_uuid_invalid, uuid}),
    do: "Could not drop rule with invalid id #{inspect uuid}"
  defp error(error),
    do: Helpers.error(error)
end
