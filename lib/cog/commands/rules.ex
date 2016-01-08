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
    response = case req.options do
      %{"add" => true} -> add_rule(req, req.args)
      %{"drop" => true} -> drop_rule(req.options)
      %{"list" => true} -> list_rules(req.options["for-command"])
      _ -> "I am not sure what action you want me to take using `rules`"
    end
    {:reply, req.reply_to, response, state}
  end

  defp add_rule(_, [expr|_]) do
    add_rule(expr)
  end
  defp add_rule(req, []) do
    case permission_expr(req.options) do
      {:error, error} ->
        error
      response ->
        response
    end
  end

  defp add_rule(expr) when is_binary(expr) do
    expr = String.replace(expr, ~r/"/, "")
    Logger.debug("expr: #{expr}")
    case Cog.RuleIngestion.ingest(expr) do
      {:ok, rule} ->
        success(rule)
      {:error, error} ->
        # TODO: this needs to handle the multiple errors returned by
        # the ingestion process
        failure(error.errors)
      _ ->
        Logger.debug("Uncaught exception in #{__MODULE__}")
        "Something went wrong, but I don't know what :("
    end
  end

  defp list_rules(nil),
    do: "ERROR! You must specify a command using the --for-command option."
  defp list_rules(cmd),
    do: list_rule(cmd) |> format_response

  defp list_rule(cmd) do
    Cog.Repo.all(Cog.Queries.Command.rules_for_cmd(cmd))
  end

  defp drop_rule(%{"id" => id}) do
    id = String.replace(id, "\"", "")

    case Cog.Repo.get_by(Cog.Models.Rule, id: id) do
      nil ->
        "There are no rules with id #{id}"
      rule ->
        Cog.Repo.delete!(rule)
        "Dropped rule with id `#{id}`:\n" <> display_rule(rule)
    end
  end
  defp drop_rule(%{"for-command" => command}) do
    query = Cog.Queries.Command.rules_for_cmd(command)

    case Cog.Repo.all(query) do
      [] ->
        "There are no rules for command #{command}"
      rules ->
        Cog.Repo.delete_all(query)
        display_rules = Enum.map(rules, &display_rule/1)
        Enum.join(["Dropped all rules for command `#{command}`:"|display_rules], "\n")
    end
  end
  defp drop_rule(_) do
    "ERROR! In order to drop rules you must pass either `--id` or `--for-command`"
  end

  def success(rule) do
    rule = Parser.json_to_rule!(rule.parse_tree)
    "Success! Added new rule \"#{rule}\""
  end

  def failure(errors) do
    error_strings = errors
    |> Enum.map(&translate_error/1)
    |> Enum.map(&("* #{&1}\n"))

    # TODO: Really should template this
    """
    Encountered the following errors:

    #{error_strings}
    """
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
      {:error, error} -> error
    end
  end
  defp permission_expr(_) do
    "Error! In order to add rules using options you must use both `--permission` and `--for-command`"
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

  defp format_response([]), do: "No rules for command found"
  defp format_response(response) do
    # TODO: get some templating back in here when that's wired back up
    build_permission_expressions(response)
  end

end
