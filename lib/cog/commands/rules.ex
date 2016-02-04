defmodule Cog.Commands.Rules do
  @moduledoc """
  This command allows the user to manage rules for commands.

  Format:
    Rules -
      rules --add "when command is <full_command_name> must have <namespace>:<permission>"
      rules --add --for-command=<full_command_name> --permission=<namespace>:<permission>
      rules --list --for-command=<full_command_name>
      rules --drop --for-command=<full_command_name>
      rules --drop --id=<rule_id>

  Examples:
  > @bot operable:rules --add "when command is operable:ec2-terminate must have operable:ec2"
  """
  use Spanner.GenCommand.Base, bundle: Cog.embedded_bundle

  #Rules command options
  option "add", type: "bool"
  option "list", type: "bool"
  option "drop", type: "bool"
  option "id", type: "string"
  option "arg0", type: "string"
  option "permission", type: "string"
  option "for-command", type: "string"

  permission "manage_commands"

  rule "when command is #{Cog.embedded_bundle}:rules must have #{Cog.embedded_bundle}:manage_commands"

  alias Piper.Permissions.Parser
  require Logger

  @built_in_namespaces ["site", Cog.embedded_bundle]

  def handle_message(req, state) do
    result = case req.options do
               %{"add" => true} -> add_rule(req, req.args)
               %{"drop" => true} -> drop_rule(req.options)
               %{"list" => true} -> list_rules(req.options["for-command"])
               _ -> {:error, "I am not sure what action you want me to take using `rules`"}
             end

    case result do
      {:ok, message} ->
        {:reply, req.reply_to, message, state}
      {:error, message} ->
        {:error, req.reply_to, message, state}
    end
  end

  defp add_rule(_, [expr|_]) do
    add_rule(expr)
  end
  defp add_rule(req, []) do
    case permission_expr(req.options) do
      {:error, _}=error ->
        error
      {:ok, _}=response ->
        response
    end
  end

  defp add_rule(expr) when is_binary(expr) do
    case Cog.RuleIngestion.ingest(expr) do
      {:ok, rule} ->
        success(rule)
      {:error, errors} when is_list(errors) ->
        # this is a keyword list
        failure(errors)
      _ ->
        Logger.debug("Uncaught exception in #{__MODULE__}")
        {:error, "Something went wrong, but I don't know what :("}
    end
  end
  defp add_rule(_),
    do: {:error, "Rule expression must be a string"}

  defp list_rules(nil),
    do: {:error, "ERROR! You must specify a command using the --for-command option."}
  defp list_rules(cmd) when is_binary(cmd) do
    case resolve_command(cmd) do
      nil ->
        {:error, "Command `#{cmd}` does not exist!"}
      %Cog.Models.Command{} ->
        list_rule(cmd) |> format_response
    end
  end
  defp list_rules(_),
    do: {:error, "Command must be a string"}

  defp list_rule(cmd) do
    Cog.Repo.all(Cog.Queries.Command.rules_for_cmd(cmd))
  end

  defp drop_rule(%{"id" => id}) do
    if Cog.UUID.is_uuid?(id) do
      case Cog.Repo.get_by(Cog.Models.Rule, id: id) do
        nil ->
          {:error, "There are no rules with id #{id}"}
        rule ->
          Cog.Repo.delete!(rule)
          {:ok, "Dropped rule with id `#{id}`:\n" <> display_rule(rule)}
      end
    else
      {:error, "Rule ID must be a UUID"}
    end
  end
  defp drop_rule(%{"for-command" => command}) when is_binary(command) do
    case resolve_command(command) do
      nil ->
        {:error, "Command `#{command}` does not exist!"}
      %Cog.Models.Command{} ->
        query = Cog.Queries.Command.rules_for_cmd(command)

        case Cog.Repo.all(query) do
          [] ->
            {:ok, "There are no rules for command #{command}"}
          rules ->
            Cog.Repo.delete_all(query)
            display_rules = Enum.map(rules, &display_rule/1)
            {:ok, Enum.join(["Dropped all rules for command `#{command}`:"|display_rules], "\n")}
        end
    end
  end
  defp drop_rule(%{"for-command" => _}),
    do: {:error, "Command must be a string"}
  defp drop_rule(_) do
    {:error, "ERROR! In order to drop rules you must pass either `--id` or `--for-command`"}
  end

  def success(rule) do
    rule = Parser.json_to_rule!(rule.parse_tree)
    {:ok, "Success! Added new rule \"#{rule}\""}
  end

  def failure(errors) do
    error_strings = errors
    |> Enum.map(&translate_error/1)
    |> Enum.map(&("* #{&1}\n"))

    # TODO: Really should template this
    {:error, """

             #{error_strings}
             """}
  end

  defp display_rule(rule) do
    resp = build_permission_expr(rule)
    "* #{resp.rule}\n"
  end

  defp translate_error({:unrecognized_command, command}),
    do: "Could not find command `#{command}`"
  defp translate_error({:unrecognized_permission, name}),
    do: "Could not find permission `#{name}`"
  defp translate_error({:no_dupes, _}),
    do: "Rule already exists"
  defp translate_error({:invalid_rule_syntax, msg}),
    do: "Invalid rule: #{msg}"
  defp translate_error(error),
    do: "#{inspect error}"

  defp permission_expr(%{"for-command" => command, "arg0" => subcommand, "permission" => permission}) do
    build_with_subcommand(command, permission, subcommand)
  end
  defp permission_expr(%{"for-command" => command, "permission" => permission}) do
    case get_namespace_permissions(command, permission) do
      [ns, perm] ->
        "when command is #{command} must have #{ns}:#{perm}"
        |> add_rule
      {:error, _}=error -> error
    end
  end
  defp permission_expr(_) do
    {:error, "Error! In order to add rules using options you must use both `--permission` and `--for-command`"}
  end

  defp get_namespace_permissions(command, permission) do
    perm_str = String.split(permission, ":")
    if length(perm_str) == 2 do
      [ns, perm] = perm_str
      if ns in [command|@built_in_namespaces] do
        [ns, perm]
      else
        {:error, "Not able to set permission for command `#{command}` to `#{permission}`"}
      end
    else
      [command, permission]
    end
  end

  defp build_with_subcommand(command, permission, [subcommand|[]]) do
    "when command is #{command} with arg[0]=='#{subcommand}' must have #{command}:#{permission}"
    |> add_rule
  end
  defp build_with_subcommand(command, permission, [subcommand|remaining]) do
    "when command is #{command} with arg[0]=='#{subcommand}' must have #{command}:#{permission}"
    |> add_rule
    build_with_subcommand(command, permission, remaining)
  end

  defp build_permission_expressions(rules) do
    build_permission_expressions(rules, [])
  end

  defp build_permission_expressions([rule | rest], strings) do
    new_strings = [build_permission_expr(rule)] ++ strings
    build_permission_expressions(rest, new_strings)
  end
  defp build_permission_expressions([], strings) do
    strings
  end

  defp build_permission_expr(%Cog.Models.Rule{}=rule) do
    ast = Parser.json_to_rule!(rule.parse_tree)
    %{id: rule.id,
      command: ast.command,
      rule: "#{ast}"}
  end

  defp format_response([]), do: {:ok, "No rules for command found"}
  defp format_response(response) do
    # TODO: get some templating back in here when that's wired back up
    {:ok, build_permission_expressions(response)}
  end

  defp resolve_command(given_name),
    do: given_name |> Cog.Queries.Command.named |> Cog.Repo.one

end
