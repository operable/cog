defmodule Cog.Commands.Trigger do
  use Cog.Command.GenCommand.Base, bundle: Cog.Util.Misc.embedded_bundle

  alias Cog.Commands.Trigger.{Create, Delete, Disable, Enable, Info, List, Update}
  require Cog.Commands.Helpers, as: Helpers

  Helpers.usage(:root)

  @description "Manage triggered pipelines"

  @arguments "<subcommand>"

  @subcommands %{
    "list" => "List all triggers (default)",
    "info <trigger>" => "Detailed information on an existing trigger",
    "create <trigger> <pipeline>" => "Create a new trigger",
    "update <trigger>" => "Update an existing trigger",
    "delete <trigger>" => "Delete an existing trigger",
    "enable <trigger>" => "Enable an existing trigger",
    "disable <trigger>" => "Disable an existing trigger"
  }

  permission "manage_triggers"

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:trigger must have #{Cog.Util.Misc.embedded_bundle}:manage_triggers"

  option "enabled", type: "bool", short: "e"
  option "description", type: "string", short: "d"
  option "name", type: "string", short: "n"
  option "pipeline", type: "string", short: "p"
  option "timeout-sec", type: "int", short: "t"
  option "as-user", type: "string", short: "u"

  def handle_message(req, state) do
    {subcommand, args} = Helpers.get_subcommand(req.args)

    result = case subcommand do
               "create"  -> Create.create(req, args)
               "delete"  -> Delete.delete(req, args)
               "disable" -> Disable.disable(req, args)
               "enable"  -> Enable.enable(req, args)
               "info"    -> Info.info(req, args)
               "list"    -> List.list(req, args)
               "update"  -> Update.update(req, args)
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
        {:reply, req.reply_to, template, convert(data), state}
      {:ok, data} ->
        {:reply, req.reply_to, convert(data), state}
      {:error, err} ->
        {:error, req.reply_to, error(err), state}
    end
  end

  ########################################################################

  defp error({:trigger_invalid, %Ecto.Changeset{}=changeset}),
    do: changeset_errors(changeset)
  defp error(error),
    do: Helpers.error(error)

  # We leverage the TriggerView from the API in order to expose the
  # trigger's invocation URL to users.
  defp convert(data) when is_list(data),
    do: Enum.map(data, &convert/1)
  defp convert(%Cog.Models.Trigger{}=trigger) do
    Cog.V1.TriggerView.render("trigger.json",
                              %{trigger: trigger})
  end
  defp convert(other),
    do: other

  defp changeset_errors(changeset) do
    msg_map = Ecto.Changeset.traverse_errors(changeset,
                                             fn
                                               {msg, opts} ->
                                                 Enum.reduce(opts, msg, fn {key, value}, acc ->
                                                   String.replace(acc, "%{#{key}}", to_string(value))
                                                 end)
                                               msg ->
                                                 msg
                                             end)

    msg_map
    |> Enum.map(fn({field, msg}) -> "#{field} #{msg}" end)
    |> Enum.join("\n")
  end

end
